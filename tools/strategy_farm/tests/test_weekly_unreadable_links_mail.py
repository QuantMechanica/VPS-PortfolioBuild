from __future__ import annotations

import csv
import datetime as dt
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = ROOT / "tools" / "strategy_farm" / "weekly_unreadable_links_mail.py"
WRAPPER_PATH = ROOT / "tools" / "strategy_farm" / "run_weekly_unreadable_links_task.py"
INSTALLER_PATH = ROOT / "tools" / "strategy_farm" / "install_weekly_unreadable_links_task.ps1"
MANIFEST_PATH = ROOT / "tools" / "strategy_farm" / "qm_tasks.manifest.ps1"
INVENTORY_PATH = ROOT / "docs" / "ops" / "SCHEDULED_TASKS_INVENTORY.md"

SPEC = importlib.util.spec_from_file_location(
    "weekly_unreadable_links_mail_under_test", MODULE_PATH
)
assert SPEC and SPEC.loader
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _write_vault(path: Path, lines: list[str]) -> None:
    path.write_text(
        "\n".join(
            [
                "# Strategie Links",
                "",
                "### Priorität A: tatsächlich offen oder nicht ausgewertet",
                "",
                subject.MARKER_START,
                *lines,
                subject.MARKER_END,
                "",
                "### Priorität B: DISCOVERY_ONLY",
                "",
                "- [ ] [Nicht mailen](https://example.com/discovery)",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def _write_leads(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "date",
        "source_mail_uid",
        "url",
        "domain_class",
        "resolved_title",
        "status",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def _paths(tmp_path: Path) -> dict[str, Path]:
    return {
        "state_file": tmp_path / "state.json",
        "claims_dir": tmp_path / "claims",
        "run_log": tmp_path / "run.jsonl",
        "latest_text": tmp_path / "latest.txt",
        "latest_html": tmp_path / "latest.html",
        "latest_json": tmp_path / "latest.json",
        "failure_dir": tmp_path / "failures",
    }


def _friday() -> dt.datetime:
    return dt.datetime(
        2026,
        7,
        24,
        6,
        30,
        tzinfo=dt.timezone(dt.timedelta(hours=2)),
    )


def test_vault_parser_selects_only_unchecked_marked_links(tmp_path: Path) -> None:
    vault = tmp_path / "Strategie Links.md"
    _write_vault(
        vault,
        [
            "- [ ] [Offen](https://example.com/open) — HTTP 403",
            "- [x] [Erledigt](https://example.com/done) — manuell gelesen",
            "- [ ] [Duplikat](http://example.com/open/) — same target",
        ],
    )

    items = subject.load_vault_links(vault)

    assert [(item.title, item.url, item.detail) for item in items] == [
        ("Offen", "https://example.com/open", "HTTP 403")
    ]


def test_vault_parser_fails_closed_on_missing_or_malformed_markers(
    tmp_path: Path,
) -> None:
    missing = tmp_path / "missing.md"
    with pytest.raises(subject.SourceDataError, match="missing"):
        subject.load_vault_links(missing)

    malformed = tmp_path / "malformed.md"
    malformed.write_text(
        f"{subject.MARKER_START}\n"
        "- [ ] Kein Markdown-Link\n"
        f"{subject.MARKER_END}\n",
        encoding="utf-8",
    )
    with pytest.raises(subject.SourceDataError, match="Malformed unchecked task"):
        subject.load_vault_links(malformed)


def test_mailbox_filter_keeps_only_source_access_failures(tmp_path: Path) -> None:
    leads = tmp_path / "leads.csv"
    rows = [
        {
            "date": "2026-07-23",
            "source_mail_uid": str(index),
            "url": f"https://example.com/{index}",
            "domain_class": "other",
            "resolved_title": f"Lead {index}",
            "status": status,
        }
        for index, status in enumerate(
            [
                "DEFERRED:SOURCE_POLICY",
                "DEFERRED:ACCESS_BLOCKED:HTTP 403",
                "DEFERRED:ROBOTS_BLOCKED",
                "DEFERRED:FETCH_ERROR:timeout",
                "DEFERRED:PERMISSION_REQUIRED",
                "DEFERRED:LOGIN_REQUIRED",
                "DEFERRED:TECHNICAL_RETRY",
                "DEFERRED:HANDOFF_FAILED:add-source",
                "NEW",
                "REJECTED:no rules",
            ],
            1,
        )
    ]
    _write_leads(leads, rows)

    items = subject.load_mailbox_deferred(leads)

    assert [item.title for item in items] == [f"Lead {i}" for i in range(1, 8)]


def test_mailbox_status_overrides_duplicate_vault_detail(tmp_path: Path) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(
        vault,
        ["- [ ] [Vault title](http://example.com/thread/) — alter Hinweis"],
    )
    _write_leads(
        leads,
        [
            {
                "date": "2026-07-23",
                "source_mail_uid": "1",
                "url": "https://example.com/thread",
                "domain_class": "other",
                "resolved_title": "Resolved title",
                "status": "DEFERRED:ACCESS_BLOCKED:HTTP 403",
            }
        ],
    )

    items = subject.collect_links(vault, leads)

    assert len(items) == 1
    assert items[0].title == "Resolved title"
    assert items[0].detail == "DEFERRED:ACCESS_BLOCKED:HTTP 403"
    assert items[0].source == "Vault + Mailbox Source Intake"


def test_mail_html_escapes_untrusted_title_and_url() -> None:
    item = subject.LinkItem(
        title='<script>alert("x")</script>',
        url="https://example.com/a?x=1&y=2",
        detail="<b>blocked</b>",
        source="test",
        status="DEFERRED:ACCESS_BLOCKED",
    )

    mail_subject, text, rendered_html = subject.build_mail([item], _friday())

    assert "1 · 24.07.2026" in mail_subject
    assert item.url in text
    assert "<script>" not in rendered_html
    assert "&lt;script&gt;" in rendered_html
    assert "x=1&amp;y=2" in rendered_html
    assert "&lt;b&gt;blocked&lt;/b&gt;" in rendered_html


def test_gmail_helper_classifies_pre_send_and_ambiguous_failures(
    tmp_path: Path,
    monkeypatch,
) -> None:
    missing_password = tmp_path / "missing-password.txt"
    missing_sender = tmp_path / "missing-sender.txt"
    monkeypatch.setattr(subject.ga, "APP_PASSWORD_FILE", missing_password)
    monkeypatch.setattr(subject.ga, "SENDER_FILE", missing_sender)

    missing = subject.ga._send_mail("subject", "body")
    assert missing["failure_stage"] == "pre_send"

    password = tmp_path / "password.txt"
    sender_file = tmp_path / "sender.txt"
    password.write_text("test-only", encoding="utf-8")
    sender_file.write_text("sender@example.com", encoding="utf-8")
    monkeypatch.setattr(subject.ga, "APP_PASSWORD_FILE", password)
    monkeypatch.setattr(subject.ga, "SENDER_FILE", sender_file)

    class FakeSMTP:
        def __init__(self, *_args, **_kwargs):
            pass

        def starttls(self):
            return None

        def login(self, *_args):
            return None

        def sendmail(self, *_args):
            raise OSError("connection lost after DATA")

        def close(self):
            return None

    monkeypatch.setattr(subject.ga.smtplib, "SMTP", FakeSMTP)
    ambiguous = subject.ga._send_mail("subject", "body")
    assert ambiguous["failure_stage"] == "send_ambiguous"


def test_gmail_helper_does_not_retry_after_acceptance_if_quit_fails(
    tmp_path: Path,
    monkeypatch,
) -> None:
    password = tmp_path / "password.txt"
    sender_file = tmp_path / "sender.txt"
    password.write_text("test-only", encoding="utf-8")
    sender_file.write_text("sender@example.com", encoding="utf-8")
    monkeypatch.setattr(subject.ga, "APP_PASSWORD_FILE", password)
    monkeypatch.setattr(subject.ga, "SENDER_FILE", sender_file)
    sends: list[int] = []

    class FakeSMTP:
        def __init__(self, *_args, **_kwargs):
            pass

        def starttls(self):
            return None

        def login(self, *_args):
            return None

        def sendmail(self, *_args):
            sends.append(1)
            return {}

        def quit(self):
            raise OSError("QUIT response lost")

        def close(self):
            return None

    monkeypatch.setattr(subject.ga.smtplib, "SMTP", FakeSMTP)
    result = subject.ga._send_mail("subject", "body")

    assert result["sent"] is True
    assert sends == [1]


def test_shared_gmail_retry_only_retries_proven_pre_send_failures(
    tmp_path: Path,
    monkeypatch,
) -> None:
    outcomes = [
        {"sent": False, "failure_stage": "pre_send"},
        {"sent": False, "failure_stage": "send_ambiguous"},
        {"sent": True},
    ]
    calls: list[int] = []

    def fake_send(*_args, **_kwargs):
        calls.append(1)
        return outcomes.pop(0)

    monkeypatch.setattr(subject.ga, "_send_mail", fake_send)
    monkeypatch.setattr(subject.ga, "DASHBOARDS_DIR", tmp_path)
    result = subject.ga._send_mail_with_retries(
        "subject",
        "body",
        attempts=3,
        base_delay_sec=0,
    )

    assert result["sent"] is False
    assert result["failure_stage"] == "send_ambiguous"
    assert len(calls) == 2


def test_dry_run_renders_but_never_sends_or_updates_state(
    tmp_path: Path,
) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(vault, ["- [ ] [Offen](https://example.com/open) — blocked"])
    _write_leads(leads, [])
    calls: list[tuple] = []

    result = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday(),
        dry_run=True,
        sender=lambda *args: calls.append(args) or {"sent": True},
        **_paths(tmp_path),
    )

    assert result["action"] == "dry_run"
    assert result["count"] == 1
    assert calls == []
    assert not (tmp_path / "state.json").exists()
    assert not (tmp_path / "run.jsonl").exists()
    assert (tmp_path / "latest.html").exists()
    assert json.loads((tmp_path / "latest.json").read_text(encoding="utf-8"))[
        "count"
    ] == 1


def test_same_iso_week_sends_at_most_once(tmp_path: Path) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(vault, ["- [ ] [Offen](https://example.com/open) — blocked"])
    _write_leads(leads, [])
    calls: list[str] = []

    def sender(mail_subject: str, _text: str, _html: str, message_id: str) -> dict:
        calls.append(message_id)
        return {"sent": True, "subject": mail_subject}

    first = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday(),
        sender=sender,
        sleep=lambda _seconds: None,
        **_paths(tmp_path),
    )
    second = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday() + dt.timedelta(days=1),
        sender=sender,
        sleep=lambda _seconds: None,
        **_paths(tmp_path),
    )

    assert first["action"] == "sent"
    assert second["action"] == "already_sent"
    assert calls == ["<qm-unreadable-links-2026-w30@quantmechanica.com>"]
    state = json.loads((tmp_path / "state.json").read_text(encoding="utf-8"))
    assert state["last_sent_week"] == "2026-W30"


def test_failed_send_is_retryable_and_does_not_claim_week(tmp_path: Path) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(vault, [])
    _write_leads(leads, [])
    calls: list[str] = []

    def sender(_subject: str, _text: str, _html: str, message_id: str) -> dict:
        calls.append(message_id)
        return {
            "sent": False,
            "reason": "smtp unavailable before delivery",
            "failure_stage": "pre_send",
        }

    result = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday(),
        sender=sender,
        sleep=lambda _seconds: None,
        **_paths(tmp_path),
    )

    assert result["action"] == "send_failed_retryable"
    assert len(calls) == 3
    state = json.loads((tmp_path / "state.json").read_text(encoding="utf-8"))
    assert state["last_attempt_stage"] == "pre_send_failed"
    assert not list((tmp_path / "claims").glob("*.json"))
    assert list((tmp_path / "failures").glob("*.md"))


def test_ambiguous_smtp_failure_is_not_retried_or_resent(
    tmp_path: Path,
) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(vault, ["- [ ] [Offen](https://example.com/open) — blocked"])
    _write_leads(leads, [])
    calls: list[str] = []

    def sender(_subject: str, _text: str, _html: str, message_id: str) -> dict:
        calls.append(message_id)
        return {
            "sent": False,
            "reason": "connection lost after DATA",
            "failure_stage": "send_ambiguous",
        }

    first = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday(),
        sender=sender,
        sleep=lambda _seconds: None,
        **_paths(tmp_path),
    )
    second = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday(),
        sender=sender,
        sleep=lambda _seconds: None,
        **_paths(tmp_path),
    )

    assert first["action"] == "send_ambiguous"
    assert first["terminal_failure"] is True
    assert second["action"] == "already_claimed"
    assert second["claim_stage"] == "ambiguous"
    assert second["terminal_failure"] is True
    assert len(calls) == 1


def test_smtp_accept_then_state_write_failure_cannot_resend(
    tmp_path: Path,
    monkeypatch,
) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(vault, ["- [ ] [Offen](https://example.com/open) — blocked"])
    _write_leads(leads, [])
    paths = _paths(tmp_path)
    calls: list[str] = []
    real_atomic_write_json = subject._atomic_write_json
    state_writes = 0

    def flaky_atomic_write_json(path: Path, payload: dict, **kwargs) -> None:
        nonlocal state_writes
        if path == paths["state_file"]:
            state_writes += 1
            if state_writes == 2:
                raise OSError("simulated state disk failure after SMTP acceptance")
        real_atomic_write_json(path, payload, **kwargs)

    monkeypatch.setattr(subject, "_atomic_write_json", flaky_atomic_write_json)

    def sender(_subject: str, _text: str, _html: str, message_id: str) -> dict:
        calls.append(message_id)
        return {"sent": True}

    with pytest.raises(OSError, match="after SMTP acceptance"):
        subject.run_report(
            vault_note=vault,
            leads_csv=leads,
            when=_friday(),
            sender=sender,
            **paths,
        )

    second = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday(),
        sender=sender,
        **paths,
    )

    assert second["action"] == "already_sent"
    assert second["claim_stage"] == "smtp_accepted"
    assert calls == ["<qm-unreadable-links-2026-w30@quantmechanica.com>"]


def test_corrupt_state_fails_closed_before_smtp(tmp_path: Path) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(vault, [])
    _write_leads(leads, [])
    paths = _paths(tmp_path)
    paths["state_file"].write_text("{not-json", encoding="utf-8")
    paths["state_file"].with_name("state.json.bak").write_text(
        json.dumps({"last_sent_week": "2026-W29"}),
        encoding="utf-8",
    )
    calls: list[tuple] = []

    with pytest.raises(subject.SourceDataError, match="possible duplicate"):
        subject.run_report(
            vault_note=vault,
            leads_csv=leads,
            when=_friday(),
            sender=lambda *args: calls.append(args) or {"sent": True},
            **paths,
        )

    assert calls == []


def test_empty_backlog_still_sends_weekly_confirmation(tmp_path: Path) -> None:
    vault = tmp_path / "Strategie Links.md"
    leads = tmp_path / "leads.csv"
    _write_vault(vault, [])
    _write_leads(leads, [])
    calls: list[str] = []

    result = subject.run_report(
        vault_note=vault,
        leads_csv=leads,
        when=_friday(),
        sender=lambda _subject, text, _html, _message_id: (
            calls.append(text) or {"sent": True}
        ),
        sleep=lambda _seconds: None,
        **_paths(tmp_path),
    )

    assert result["action"] == "sent"
    assert result["count"] == 0
    assert "Keine offenen" in calls[0]


def test_scheduler_and_manifest_contracts() -> None:
    installer = INSTALLER_PATH.read_text(encoding="utf-8")
    manifest = MANIFEST_PATH.read_text(encoding="utf-8")
    inventory = INVENTORY_PATH.read_text(encoding="utf-8")

    assert "QM_StrategyFarm_UnreadableLinks_Friday" in installer
    assert "-Weekly" in installer
    assert "-DaysOfWeek Friday" in installer
    assert "[string]$At = '06:30'" in installer
    assert "-LogonType Interactive" in installer
    assert "-UserId $UserId" in installer
    assert "-MultipleInstances IgnoreNew" in installer
    assert "-RestartCount 4" in installer
    assert "Start-ScheduledTask" not in installer

    always_on = manifest.split("$QM_ALWAYSON_TASKS = @(", 1)[1].split("\n)", 1)[0]
    enforce_disabled = manifest.split(
        "$QM_ENFORCE_DISABLED_TASKS = @(", 1
    )[1].split("\n)", 1)[0]
    assert "QM_StrategyFarm_UnreadableLinks_Friday" in always_on
    assert "QM_StrategyFarm_UnreadableLinks_Friday" not in enforce_disabled
    assert "QM_StrategyFarm_GmailAlarm_Hourly" in enforce_disabled
    assert "Friday 06:30" in inventory


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell parser only")
def test_windows_powershell_parses_installer() -> None:
    parser = (
        "$tokens=$null;$errors=$null;"
        f"[System.Management.Automation.Language.Parser]::ParseFile("
        f"'{INSTALLER_PATH}',[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count){$errors|ForEach-Object{Write-Error $_};exit 1}"
    )
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", parser),
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr


def test_wrapper_and_core_compile() -> None:
    result = subprocess.run(
        (sys.executable, "-m", "py_compile", str(MODULE_PATH), str(WRAPPER_PATH)),
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
