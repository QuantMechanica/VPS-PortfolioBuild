from __future__ import annotations

import datetime as dt
import importlib.util
import json
import os
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "tools" / "strategy_farm"
MODULE_PATH = TOOLS / "reboot_diagnostic_mail.py"
WRAPPER = TOOLS / "run_reboot_diagnostic_mail_task.py"
INSTALLER = TOOLS / "install_reboot_diagnostic_mail_scheduled_task.ps1"
WATCHDOG = TOOLS / "factory_watchdog.ps1"
MANIFEST = TOOLS / "qm_tasks.manifest.ps1"
GMAIL_INSTALLER = TOOLS / "install_gmail_alarm_scheduled_task.ps1"
GMAIL_ALARM = TOOLS / "gmail_alarm.py"

SPEC = importlib.util.spec_from_file_location("reboot_diagnostic_mail_under_test", MODULE_PATH)
assert SPEC and SPEC.loader
subject = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(subject)


REQUESTED = dt.datetime(2026, 7, 23, 3, 50, tzinfo=dt.timezone.utc)
BOOT = dt.datetime(2026, 7, 23, 3, 51, 28, tzinfo=dt.timezone.utc)


def _incident() -> dict:
    return {
        "schema": 1,
        "event_id": "08fa1932-cad5-4ee7-9df5-c0b18ec20213",
        "source": subject.EXPECTED_SOURCE,
        "kind": subject.EXPECTED_KIND,
        "requested_at_utc": "2026-07-23T03:50:00Z",
        "pending_since_utc": "2026-07-23T03:45:00Z",
        "shutdown_comment": (
            "QM factory_watchdog: interactive session lost - "
            "auto-reboot to restore autologon session"
        ),
        "workers": 0,
        "expected_workers": 9,
        "session_lost": True,
        "active_count": 0,
        "pending_count": 2634,
        "terminal_count": 0,
    }


def _context() -> dict:
    comment = _incident()["shutdown_comment"]
    return {
        "boot_utc": "2026-07-23T03:51:28Z",
        "collected_at_utc": "2026-07-23T03:56:30Z",
        "system_events": [
            {
                "id": 1074,
                "provider": "User32",
                "time_utc": "2026-07-23T03:50:03Z",
                "message": f"shutdown.exe initiated restart. Comment: {comment}",
            },
            {
                "id": 6005,
                "provider": "EventLog",
                "time_utc": "2026-07-23T03:51:36Z",
                "message": "The Event log service was started.",
            },
        ],
        "application_events": [],
        "session_events": [
            {
                "id": 45,
                "provider": "Microsoft-Windows-TerminalServices-LocalSessionManager",
                "time_utc": "2026-07-23T03:47:16Z",
                "message": "Windows Subsystem took too long to process Terminate.",
            }
        ],
        "task_events": [
            {
                "id": 201,
                "provider": "Microsoft-Windows-TaskScheduler",
                "time_utc": "2026-07-23T03:41:50Z",
                "message": "Action completed with return code 3221225794.",
            }
        ],
        "recovery": {
            "target_user": "qm-admin",
            "session_exists": True,
            "session_state": "Active",
            "workers": 9,
            "factory_terminals": 9,
            "live_terminals": 2,
            "factory_on_last_result": 0,
        },
    }


def _watchdog_records() -> list[dict]:
    return [
        {
            "ts": "2026-07-23T03:40:02Z",
            "workers": 9,
            "expect": 9,
            "session_lost": False,
            "action": "noop_healthy",
            "active_items": [
                {
                    "id": "work-1",
                    "ea_id": "QM5_1127",
                    "phase": "Q02",
                    "terminal": "T3",
                }
            ],
            "resource": {
                "committed_gb": 118.0,
                "commit_limit_gb": 122.0,
                "commit_headroom_gb": 4.0,
                "commit_percent": 96.7,
                "pagefile_allocated_mb": 60655,
                "pagefile_current_mb": 60000,
                "pagefile_percent": 98.9,
                "pages_per_sec": 10708,
                "top_processes": [
                    {
                        "name": "metatester64",
                        "pid": 16548,
                        "session_id": 1,
                        "private_gb": 37.9,
                        "working_set_gb": 8.0,
                    }
                ],
            },
        },
        {
            "ts": "2026-07-23T03:45:02Z",
            "workers": 0,
            "expect": 9,
            "session_lost": True,
            "action": "session_lost_pending_confirm",
        },
        {
            "ts": "2026-07-23T03:50:02Z",
            "workers": 0,
            "expect": 9,
            "session_lost": True,
            "action": "healed_session_reboot",
        },
    ]


def _write_jsonl(path: Path, records: list[dict]) -> None:
    path.write_text(
        "".join(json.dumps(record) + "\n" for record in records),
        encoding="utf-8",
    )


def _generic_context(boot: dt.datetime, events: list[dict]) -> dict:
    return {
        "computer": "QM-TEST",
        "boot_utc": subject._iso(boot),
        "collected_at_utc": subject._iso(boot + dt.timedelta(minutes=6)),
        "system_events": events,
        "application_events": [],
        "session_events": [],
        "task_events": [],
        "recovery": {
            "target_user": "qm-admin",
            "session_exists": True,
            "session_state": "Active",
            "workers": 9,
            "factory_terminals": 9,
            "live_terminals": 2,
            "factory_on_last_result": 0,
        },
    }


def test_verified_watchdog_reboot_builds_evidence_based_mail(monkeypatch, tmp_path: Path) -> None:
    registry = tmp_path / "multisymbol_eas.txt"
    registry.write_text("QM5_1127\n", encoding="utf-8")
    monkeypatch.setattr(subject, "MULTISYMBOL_REGISTRY", registry)

    valid, reason, event = subject.validate_incident(
        _incident(),
        _context(),
        now=BOOT + dt.timedelta(minutes=6),
    )
    assert valid is True
    assert reason == "verified"
    assert event and event["id"] == 1074

    analysis = subject.analyze_incident(_incident(), _context(), _watchdog_records(), [])
    mail_subject, text, rendered_html = subject.build_mail(_incident(), _context(), analysis)

    assert "Neustart erklärt" in mail_subject
    assert analysis["confidence"] == "hoch"
    assert "Commit-/Pagefile-Druck" in text
    assert "metatester64 PID 16548" in text
    assert "0xC0000142" in text
    assert "QM5_1127 Q02 · Multisymbol" in text
    assert "kein Kernel-Power-41" in text
    assert "Factory-Worker: 9/9" in text
    assert "BESTÄTIGTER AUSLÖSER" in rendered_html


def test_validation_rejects_marker_without_matching_user32_event() -> None:
    context = _context()
    context["system_events"] = []
    valid, reason, event = subject.validate_incident(
        _incident(),
        context,
        now=BOOT + dt.timedelta(minutes=6),
    )
    assert valid is False
    assert reason == "matching_user32_1074_missing"
    assert event is None


def test_validation_rejects_marker_without_shutdown_comment() -> None:
    incident = _incident()
    incident["shutdown_comment"] = ""

    valid, reason, event = subject.validate_incident(
        incident,
        _context(),
        now=BOOT + dt.timedelta(minutes=6),
    )

    assert valid is False
    assert reason == "marker_missing_shutdown_comment"
    assert event is None


def test_validation_rejects_1074_from_wrong_provider() -> None:
    context = _context()
    context["system_events"][0]["provider"] = "Synthetic-User32-Provider"

    valid, reason, event = subject.validate_incident(
        _incident(),
        context,
        now=BOOT + dt.timedelta(minutes=6),
    )

    assert valid is False
    assert reason == "matching_user32_1074_missing"
    assert event is None


def test_validation_rejects_marker_that_precedes_another_boot() -> None:
    context = _context()
    second_boot = BOOT + dt.timedelta(minutes=5)
    context["boot_utc"] = subject._iso(second_boot)

    valid, reason, event = subject.validate_incident(
        _incident(),
        context,
        now=second_boot + dt.timedelta(minutes=6),
    )

    assert valid is False
    assert reason == "marker_precedes_another_boot"
    assert event is None


def test_validation_uses_latest_matching_shutdown_event_when_events_are_unsorted() -> None:
    context = _context()
    comment = _incident()["shutdown_comment"]
    older = {
        "id": 1074,
        "provider": "User32",
        "time_utc": subject._iso(REQUESTED + dt.timedelta(seconds=1)),
        "message": f"shutdown.exe initiated restart. Comment: {comment}",
    }
    latest = {
        "id": 1074,
        "provider": "User32",
        "time_utc": subject._iso(REQUESTED + dt.timedelta(seconds=3)),
        "message": f"shutdown.exe initiated restart. Comment: {comment}",
    }
    context["system_events"] = [older, latest, context["system_events"][1]]

    valid, reason, event = subject.validate_incident(
        _incident(),
        context,
        now=BOOT + dt.timedelta(minutes=6),
    )

    assert valid is True
    assert reason == "verified"
    assert event is latest


def test_processed_watchdog_marker_is_not_reused_for_second_boot_within_30m(
    monkeypatch,
    tmp_path: Path,
) -> None:
    second_boot = BOOT + dt.timedelta(minutes=5)
    context = _generic_context(
        second_boot,
        [
            _context()["system_events"][0],
            {
                "id": 41,
                "provider": "Microsoft-Windows-Kernel-Power",
                "time_utc": subject._iso(second_boot + dt.timedelta(seconds=2)),
                "message": "The system rebooted without cleanly shutting down first.",
            },
        ],
    )
    pending = tmp_path / "pending.json"
    pending.write_text(json.dumps(_incident()), encoding="utf-8")
    state = tmp_path / "state.json"
    state.write_text(
        json.dumps(
            {
                "schema": 1,
                "last_observed_boot_utc": subject._iso(BOOT),
                "events": {
                    _incident()["event_id"]: {
                        "status": "sent",
                        "boot_utc": subject._iso(BOOT),
                    }
                },
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(subject, "_utc_now", lambda: second_boot + dt.timedelta(minutes=6))
    sent: list[str] = []

    result = subject.process_pending(
        pending_file=pending,
        state_file=state,
        watchdog_log=tmp_path / "watchdog.jsonl",
        live_watchdog_log=tmp_path / "live.jsonl",
        report_dir=tmp_path / "reports",
        run_log=tmp_path / "run.jsonl",
        context_loader=lambda: context,
        sender=lambda mail_subject, _text, _html: (
            sent.append(mail_subject) or {"sent": True}
        ),
    )

    assert result["action"] == "mail_sent"
    assert len(sent) == 1
    assert "Ungeplanter Neustart" in sent[0]
    report = json.loads(Path(result["reports"]["json"]).read_text(encoding="utf-8"))
    assert (
        report["incident"]["marker_ignored_reason"]
        == "marker_already_processed_for_previous_boot"
    )
    assert report["incident"]["trigger_class"] == "unexpected"


def test_full_pagefile_plus_large_tester_is_not_high_confidence_by_itself() -> None:
    records = _watchdog_records()
    records[0]["resource"].update(
        {
            "committed_gb": 86.0,
            "commit_limit_gb": 122.0,
            "commit_headroom_gb": 36.0,
            "commit_percent": 70.5,
            "pagefile_percent": 96.0,
            "pages_per_sec": 55,
        }
    )
    context = _context()
    context["task_events"] = []
    context["application_events"] = []
    analysis = subject.analyze_incident(_incident(), context, records, [])
    assert analysis["confidence"] == "mittel"
    assert "eindeutige automatische Zuordnung" in analysis["root_cause"]


def test_process_pending_is_at_most_once(monkeypatch, tmp_path: Path) -> None:
    pending = tmp_path / "pending.json"
    state = tmp_path / "state.json"
    watchdog = tmp_path / "watchdog.jsonl"
    live = tmp_path / "live.jsonl"
    reports = tmp_path / "reports"
    run_log = tmp_path / "run.jsonl"
    pending.write_text(json.dumps(_incident()), encoding="utf-8")
    _write_jsonl(watchdog, _watchdog_records())
    _write_jsonl(live, [])
    monkeypatch.setattr(subject, "_utc_now", lambda: BOOT + dt.timedelta(minutes=6))
    monkeypatch.setattr(subject, "MULTISYMBOL_REGISTRY", tmp_path / "missing.txt")

    sent: list[str] = []

    def fake_sender(mail_subject: str, _text: str, _html: str | None) -> dict:
        sent.append(mail_subject)
        return {"sent": True, "subject": mail_subject}

    kwargs = {
        "pending_file": pending,
        "state_file": state,
        "watchdog_log": watchdog,
        "live_watchdog_log": live,
        "report_dir": reports,
        "run_log": run_log,
        "context_loader": _context,
        "sender": fake_sender,
    }
    first = subject.process_pending(**kwargs)
    second = subject.process_pending(**kwargs)

    assert first["action"] == "mail_sent"
    assert second["action"] == "noop_already_processed"
    assert len(sent) == 1
    stored = json.loads(state.read_text(encoding="utf-8"))
    assert stored["events"][_incident()["event_id"]]["status"] == "sent"
    assert len(list(reports.glob("*.json"))) == 1


def test_transient_sender_failure_retries_within_one_claim() -> None:
    attempts = []

    def flaky_sender(_subject: str, _text: str, _html: str | None) -> dict:
        attempts.append(len(attempts) + 1)
        if len(attempts) == 1:
            return {"sent": False, "reason": "smtp failed: network unavailable"}
        return {"sent": True}

    result = subject._send_with_retries(
        flaky_sender,
        "subject",
        "text",
        "<html></html>",
        sleeper=lambda _seconds: None,
    )
    assert result["sent"] is True
    assert result["attempt"] == 2
    assert attempts == [1, 2]


def test_failed_delivery_is_retried_for_the_same_boot(
    monkeypatch,
    tmp_path: Path,
) -> None:
    new_boot = BOOT + dt.timedelta(days=1)
    context = _generic_context(
        new_boot,
        [
            {
                "id": 1074,
                "provider": "User32",
                "time_utc": subject._iso(new_boot - dt.timedelta(minutes=1)),
                "message": "maintenance process requested restart",
            }
        ],
    )
    state = tmp_path / "state.json"
    state.write_text(
        json.dumps({"schema": 1, "last_observed_boot_utc": subject._iso(BOOT), "events": {}}),
        encoding="utf-8",
    )
    watchdog = tmp_path / "watchdog.jsonl"
    live = tmp_path / "live.jsonl"
    _write_jsonl(watchdog, [])
    _write_jsonl(live, [])
    monkeypatch.setattr(subject, "_utc_now", lambda: new_boot + dt.timedelta(minutes=6))
    common = {
        "pending_file": tmp_path / "missing-pending.json",
        "state_file": state,
        "watchdog_log": watchdog,
        "live_watchdog_log": live,
        "report_dir": tmp_path / "reports",
        "run_log": tmp_path / "run.jsonl",
        "context_loader": lambda: context,
    }

    failed = subject.process_pending(
        **common,
        sender=lambda _mail_subject, _text, _html: {
            "sent": False,
            "reason": "Gmail credentials missing in .private/secrets/",
        },
    )
    sent_subjects: list[str] = []
    retried = subject.process_pending(
        **common,
        sender=lambda mail_subject, _text, _html: (
            sent_subjects.append(mail_subject) or {"sent": True}
        ),
    )
    final_noop = subject.process_pending(
        **common,
        sender=lambda _mail_subject, _text, _html: pytest.fail("must not send twice"),
    )

    assert failed["action"] == "mail_failed"
    assert retried["action"] == "mail_sent"
    assert final_noop["action"] == "noop_boot_already_observed"
    assert len(sent_subjects) == 1
    stored = json.loads(state.read_text(encoding="utf-8"))
    event = next(
        value
        for value in stored["events"].values()
        if value.get("boot_utc") == subject._iso(new_boot)
    )
    assert event["status"] == "sent"
    assert event["delivery_cycle"] == 2
    claim_files = list(state.with_name(f"{state.stem}_claims").glob("*.claim"))
    assert len(claim_files) == 2


def test_abandoned_claim_is_retried_in_the_next_delivery_cycle(
    monkeypatch,
    tmp_path: Path,
) -> None:
    new_boot = BOOT + dt.timedelta(days=1)
    context = _generic_context(
        new_boot,
        [
            {
                "id": 1074,
                "provider": "User32",
                "time_utc": subject._iso(new_boot - dt.timedelta(minutes=1)),
                "message": "maintenance process requested restart",
            }
        ],
    )
    incident = subject._generic_boot_incident(context)
    state = tmp_path / "state.json"
    state.write_text(
        json.dumps({"schema": 1, "last_observed_boot_utc": subject._iso(BOOT), "events": {}}),
        encoding="utf-8",
    )
    claimed, _stored = subject._claim_event(state, incident, context["boot_utc"])
    assert claimed is True
    monkeypatch.setattr(subject, "_pid_alive", lambda _pid: False)
    monkeypatch.setattr(subject, "_utc_now", lambda: new_boot + dt.timedelta(minutes=6))
    sent: list[str] = []

    result = subject.process_pending(
        pending_file=tmp_path / "missing-pending.json",
        state_file=state,
        watchdog_log=tmp_path / "watchdog.jsonl",
        live_watchdog_log=tmp_path / "live.jsonl",
        report_dir=tmp_path / "reports",
        run_log=tmp_path / "run.jsonl",
        context_loader=lambda: context,
        sender=lambda mail_subject, _text, _html: (
            sent.append(mail_subject) or {"sent": True}
        ),
    )

    assert result["action"] == "mail_sent"
    assert len(sent) == 1
    stored = json.loads(state.read_text(encoding="utf-8"))
    event = stored["events"][incident["event_id"]]
    assert event["status"] == "sent"
    assert event["delivery_cycle"] == 2
    assert len(list(state.with_name(f"{state.stem}_claims").glob("*.claim"))) == 2


def test_live_claim_is_not_retried_concurrently(tmp_path: Path) -> None:
    new_boot = BOOT + dt.timedelta(days=1)
    context = _generic_context(new_boot, [])
    incident = subject._generic_boot_incident(context)
    state = tmp_path / "state.json"
    state.write_text(
        json.dumps({"schema": 1, "last_observed_boot_utc": subject._iso(BOOT), "events": {}}),
        encoding="utf-8",
    )

    first, _stored = subject._claim_event(state, incident, context["boot_utc"])
    second, _stored = subject._claim_event(state, incident, context["boot_utc"])

    assert first is True
    assert second is False
    stored = json.loads(state.read_text(encoding="utf-8"))
    assert stored["events"][incident["event_id"]]["delivery_cycle"] == 1


def test_reused_owner_pid_does_not_keep_abandoned_claim_alive(monkeypatch) -> None:
    claimed_at = BOOT + dt.timedelta(minutes=1)
    original_process_start = claimed_at - dt.timedelta(minutes=1)
    reused_process_start = claimed_at + dt.timedelta(minutes=2)
    claim = {
        "status": "claimed",
        "claimed_at_utc": subject._iso(claimed_at),
        "claim_owner_pid": 4242,
        "claim_owner_started_utc": subject._iso(original_process_start),
    }
    monkeypatch.setattr(subject, "_pid_alive", lambda _pid: True)
    monkeypatch.setattr(subject, "_process_started_utc", lambda _pid: reused_process_start)

    assert subject._claimed_delivery_abandoned(
        claim,
        current=claimed_at + dt.timedelta(minutes=3),
    )


def test_corrupt_primary_state_recovers_from_atomic_backup(
    monkeypatch,
    tmp_path: Path,
) -> None:
    new_boot = BOOT + dt.timedelta(days=1)
    context = _generic_context(new_boot, [])
    state = tmp_path / "state.json"
    subject._atomic_write_json(
        state,
        {"schema": 1, "last_observed_boot_utc": subject._iso(BOOT), "events": {}},
        keep_backup=True,
    )
    state.write_text("{broken", encoding="utf-8")
    monkeypatch.setattr(subject, "_utc_now", lambda: new_boot + dt.timedelta(minutes=6))
    sent: list[str] = []

    result = subject.process_pending(
        pending_file=tmp_path / "missing-pending.json",
        state_file=state,
        watchdog_log=tmp_path / "watchdog.jsonl",
        live_watchdog_log=tmp_path / "live.jsonl",
        report_dir=tmp_path / "reports",
        run_log=tmp_path / "run.jsonl",
        context_loader=lambda: context,
        sender=lambda mail_subject, _text, _html: (
            sent.append(mail_subject) or {"sent": True}
        ),
    )

    assert result["action"] == "mail_sent"
    assert len(sent) == 1
    repaired = json.loads(state.read_text(encoding="utf-8"))
    mirrored = json.loads(state.with_name(f"{state.name}.bak").read_text(encoding="utf-8"))
    assert repaired == mirrored
    assert repaired["last_observed_boot_utc"] == subject._iso(new_boot)


@pytest.mark.parametrize("state_text", ["{broken", "{}"])
def test_corrupt_state_without_backup_fails_instead_of_suppressing_boot(
    monkeypatch,
    tmp_path: Path,
    state_text: str,
) -> None:
    state = tmp_path / "state.json"
    state.write_text(state_text, encoding="utf-8")
    monkeypatch.setattr(subject, "_utc_now", lambda: BOOT + dt.timedelta(minutes=6))

    result = subject.process_pending(
        pending_file=tmp_path / "missing-pending.json",
        state_file=state,
        watchdog_log=tmp_path / "watchdog.jsonl",
        live_watchdog_log=tmp_path / "live.jsonl",
        report_dir=tmp_path / "reports",
        run_log=tmp_path / "run.jsonl",
        context_loader=lambda: _generic_context(BOOT, []),
        sender=lambda _mail_subject, _text, _html: pytest.fail("must not send"),
    )

    assert result["action"] == "state_failed"


def test_corrupt_backup_without_primary_is_not_treated_as_first_install(
    monkeypatch,
    tmp_path: Path,
) -> None:
    state = tmp_path / "state.json"
    state.with_name(f"{state.name}.bak").write_text("{broken", encoding="utf-8")
    monkeypatch.setattr(subject, "_utc_now", lambda: BOOT + dt.timedelta(minutes=6))

    result = subject.process_pending(
        pending_file=tmp_path / "missing-pending.json",
        state_file=state,
        watchdog_log=tmp_path / "watchdog.jsonl",
        live_watchdog_log=tmp_path / "live.jsonl",
        report_dir=tmp_path / "reports",
        run_log=tmp_path / "run.jsonl",
        context_loader=lambda: _generic_context(BOOT, []),
        sender=lambda _mail_subject, _text, _html: pytest.fail("must not send"),
    )

    assert result["action"] == "state_failed"


def test_installation_baseline_sends_no_mail(monkeypatch, tmp_path: Path) -> None:
    state = tmp_path / "state.json"
    run_log = tmp_path / "run.jsonl"
    context = _generic_context(BOOT, [])
    monkeypatch.setattr(subject, "_utc_now", lambda: BOOT + dt.timedelta(minutes=6))

    result = subject.initialize_current_boot(
        state_file=state,
        run_log=run_log,
        context_loader=lambda: context,
    )

    assert result["action"] == "baseline_initialized"
    stored = json.loads(state.read_text(encoding="utf-8"))
    assert stored["last_observed_boot_utc"] == "2026-07-23T03:51:28Z"
    assert stored["events"] == {}


def test_generic_planned_reboot_without_marker_sends_once_per_boot(
    monkeypatch,
    tmp_path: Path,
) -> None:
    new_boot = BOOT + dt.timedelta(days=1)
    event_time = new_boot - dt.timedelta(minutes=1)
    context = _generic_context(
        new_boot,
        [
            {
                "id": 1074,
                "provider": "User32",
                "time_utc": subject._iso(event_time),
                "message": (
                    "svchost.exe initiated restart on behalf of SYSTEM. "
                    "Reason: Operating System: Service pack (Planned)"
                ),
            },
            {
                "id": 6005,
                "provider": "EventLog",
                "time_utc": subject._iso(new_boot + dt.timedelta(seconds=8)),
                "message": "Event log started.",
            },
        ],
    )
    state = tmp_path / "state.json"
    state.write_text(
        json.dumps({"schema": 1, "last_observed_boot_utc": subject._iso(BOOT), "events": {}}),
        encoding="utf-8",
    )
    watchdog = tmp_path / "watchdog.jsonl"
    live = tmp_path / "live.jsonl"
    _write_jsonl(watchdog, [])
    _write_jsonl(live, [])
    sent: list[tuple[str, str]] = []
    monkeypatch.setattr(subject, "_utc_now", lambda: new_boot + dt.timedelta(minutes=6))

    kwargs = {
        "pending_file": tmp_path / "missing-pending.json",
        "state_file": state,
        "watchdog_log": watchdog,
        "live_watchdog_log": live,
        "report_dir": tmp_path / "reports",
        "run_log": tmp_path / "run.jsonl",
        "context_loader": lambda: context,
        "sender": lambda mail_subject, text, _html: (
            sent.append((mail_subject, text)) or {"sent": True}
        ),
    }
    first = subject.process_pending(**kwargs)
    second = subject.process_pending(**kwargs)

    assert first["action"] == "mail_sent"
    assert second["action"] == "noop_boot_already_observed"
    assert len(sent) == 1
    assert "Geplanter Windows-Neustart" in sent[0][0]
    assert "Windows Event 1074" in sent[0][1]
    stored = json.loads(state.read_text(encoding="utf-8"))
    assert stored["last_observed_boot_utc"] == subject._iso(new_boot)


def test_stale_watchdog_marker_does_not_block_generic_unexpected_boot(
    monkeypatch,
    tmp_path: Path,
) -> None:
    new_boot = BOOT + dt.timedelta(days=2)
    context = _generic_context(
        new_boot,
        [
            {
                "id": 41,
                "provider": "Microsoft-Windows-Kernel-Power",
                "time_utc": subject._iso(new_boot + dt.timedelta(seconds=2)),
                "message": "The system rebooted without cleanly shutting down first.",
            },
            {
                "id": 6008,
                "provider": "EventLog",
                "time_utc": subject._iso(new_boot + dt.timedelta(seconds=5)),
                "message": "The previous system shutdown was unexpected.",
            },
        ],
    )
    pending = tmp_path / "pending.json"
    pending.write_text(json.dumps(_incident()), encoding="utf-8")
    state = tmp_path / "state.json"
    state.write_text(
        json.dumps({"schema": 1, "last_observed_boot_utc": subject._iso(BOOT), "events": {}}),
        encoding="utf-8",
    )
    monkeypatch.setattr(subject, "_utc_now", lambda: new_boot + dt.timedelta(minutes=6))
    sent: list[str] = []

    result = subject.process_pending(
        pending_file=pending,
        state_file=state,
        watchdog_log=tmp_path / "watchdog.jsonl",
        live_watchdog_log=tmp_path / "live.jsonl",
        report_dir=tmp_path / "reports",
        run_log=tmp_path / "run.jsonl",
        context_loader=lambda: context,
        sender=lambda mail_subject, _text, _html: (
            sent.append(mail_subject) or {"sent": True}
        ),
    )

    assert result["action"] == "mail_sent"
    assert len(sent) == 1
    assert "Ungeplanter Neustart" in sent[0]
    report = json.loads(Path(result["reports"]["json"]).read_text(encoding="utf-8"))
    assert report["incident"]["marker_ignored_reason"] == "marker_stale"


def test_bugcheck_has_priority_and_old_kernel_event_is_ignored() -> None:
    boot = BOOT + dt.timedelta(days=3)
    incident = subject._generic_boot_incident(
        _generic_context(
            boot,
            [
                {
                    "id": 41,
                    "provider": "Microsoft-Windows-Kernel-Power",
                    "time_utc": subject._iso(boot - dt.timedelta(minutes=20)),
                    "message": "old unrelated kernel event",
                },
                {
                    "id": 1001,
                    "provider": "Microsoft-Windows-WER-SystemErrorReporting",
                    "time_utc": subject._iso(boot + dt.timedelta(seconds=20)),
                    "message": "The computer has rebooted from a bugcheck.",
                },
            ],
        )
    )

    assert incident["trigger_class"] == "bugcheck"
    assert incident["trigger_event"]["id"] == 1001
    assert all(
        event["message"] != "old unrelated kernel event"
        for event in incident["evidence_events"]
    )


def test_planned_intent_plus_kernel_power_is_classified_unclean() -> None:
    boot = BOOT + dt.timedelta(days=4)
    incident = subject._generic_boot_incident(
        _generic_context(
            boot,
            [
                {
                    "id": 1074,
                    "provider": "User32",
                    "time_utc": subject._iso(boot - dt.timedelta(minutes=1)),
                    "message": "maintenance process requested restart",
                },
                {
                    "id": 41,
                    "provider": "Microsoft-Windows-Kernel-Power",
                    "time_utc": subject._iso(boot + dt.timedelta(seconds=1)),
                    "message": "unclean shutdown",
                },
            ],
        )
    )

    assert incident["trigger_class"] == "planned_unclean"
    assert incident["trigger_confidence"] == "hoch"


def test_watchdog_intent_plus_kernel_power_is_classified_unclean() -> None:
    boot = BOOT + dt.timedelta(days=5)
    incident = subject._generic_boot_incident(
        _generic_context(
            boot,
            [
                {
                    "id": 1074,
                    "provider": "User32",
                    "time_utc": subject._iso(boot - dt.timedelta(minutes=1)),
                    "message": (
                        "QM factory_watchdog: interactive session lost - "
                        "auto-reboot to restore autologon session"
                    ),
                },
                {
                    "id": 41,
                    "provider": "Microsoft-Windows-Kernel-Power",
                    "time_utc": subject._iso(boot + dt.timedelta(seconds=1)),
                    "message": "unclean shutdown",
                },
            ],
        )
    )

    assert incident["trigger_class"] == "planned_unclean"
    assert "QM-Watchdog" in incident["trigger_title"]


def test_generic_boot_classifier_ignores_event_ids_from_wrong_providers() -> None:
    boot = BOOT + dt.timedelta(days=5, hours=1)
    incident = subject._generic_boot_incident(
        _generic_context(
            boot,
            [
                {
                    "id": 1074,
                    "provider": "Synthetic-User32-Provider",
                    "time_utc": subject._iso(boot - dt.timedelta(minutes=1)),
                    "message": "fake planned restart",
                },
                {
                    "id": 41,
                    "provider": "Not-Microsoft-Windows-Kernel-Power-Test",
                    "time_utc": subject._iso(boot + dt.timedelta(seconds=1)),
                    "message": "fake unclean restart",
                },
                {
                    "id": 6008,
                    "provider": "Synthetic-EventLog-Provider",
                    "time_utc": subject._iso(boot + dt.timedelta(seconds=2)),
                    "message": "fake unexpected shutdown",
                },
            ],
        )
    )

    assert incident["trigger_class"] == "unknown"
    assert incident["trigger_event"] is None


@pytest.mark.parametrize("event_id", [1074, 109])
def test_post_boot_shutdown_event_is_not_used_as_boot_cause(event_id: int) -> None:
    boot = BOOT + dt.timedelta(days=6)
    incident = subject._generic_boot_incident(
        _generic_context(
            boot,
            [
                {
                    "id": event_id,
                    "provider": "User32" if event_id == 1074 else "Microsoft-Windows-Kernel-Power",
                    "time_utc": subject._iso(boot + dt.timedelta(minutes=1)),
                    "message": "event recorded after the completed boot",
                }
            ],
        )
    )

    assert incident["trigger_class"] == "unknown"
    assert incident["trigger_event"] is None


def test_only_preboot_system_event_26_is_resource_evidence() -> None:
    preboot_context = _context()
    preboot_context["task_events"] = []
    preboot_context["system_events"].append(
        {
            "id": 26,
            "provider": "Application Popup",
            "time_utc": subject._iso(BOOT - dt.timedelta(minutes=1)),
            "message": "Windows successfully diagnosed a low virtual memory condition.",
        }
    )
    preboot = subject.analyze_incident(_incident(), preboot_context, [], [])

    postboot_context = _context()
    postboot_context["task_events"] = []
    postboot_context["system_events"].append(
        {
            "id": 26,
            "provider": "Application Popup",
            "time_utc": subject._iso(BOOT + dt.timedelta(minutes=1)),
            "message": "Windows successfully diagnosed a low virtual memory condition.",
        }
    )
    postboot = subject.analyze_incident(_incident(), postboot_context, [], [])

    signal = "Windows-Warnung zu niedrigem virtuellem Speicher"
    assert signal in preboot["pressure_signals"]
    assert signal not in postboot["pressure_signals"]


def test_verified_watchdog_mail_reports_unclean_completion() -> None:
    context = _context()
    context["system_events"].append(
        {
            "id": 41,
            "provider": "Microsoft-Windows-Kernel-Power",
            "time_utc": subject._iso(BOOT + dt.timedelta(seconds=1)),
            "message": "The system rebooted without cleanly shutting down first.",
        }
    )
    analysis = subject.analyze_incident(_incident(), context, _watchdog_records(), [])
    _mail_subject, text, rendered_html = subject.build_mail(_incident(), context, analysis)

    assert "unsauberen Abschluss" in text
    assert "unsauberen Abschluss" in rendered_html
    assert "kein Kernel-Power-41" not in text


def test_manifest_keeps_morning_brief_and_disables_pipeline_alarm() -> None:
    source = MANIFEST.read_text(encoding="utf-8")
    always_on = source.split("$QM_ALWAYSON_TASKS = @(", 1)[1].split("\n)", 1)[0]
    enforce_disabled = source.split("$QM_ENFORCE_DISABLED_TASKS = @(", 1)[1].split("\n)", 1)[0]
    assert "QM_MorningBriefing_Vault" in always_on
    assert "QM_StrategyFarm_RebootDiagnostic_AtStartup" in always_on
    assert "QM_StrategyFarm_GmailAlarm_Hourly" not in always_on
    assert "QM_StrategyFarm_GmailAlarm_Hourly" in enforce_disabled
    installer = GMAIL_INSTALLER.read_text(encoding="utf-8")
    assert "Disable-ScheduledTask -TaskName $TaskName" in installer
    assert "Enable-ScheduledTask -TaskName $TaskName" not in installer
    alarm = GMAIL_ALARM.read_text(encoding="utf-8")
    assert "PIPELINE_ALERTS_ENABLED = False" in alarm
    assert "if not PIPELINE_ALERTS_ENABLED:" in alarm


def test_watchdog_stages_diagnostic_before_shutdown() -> None:
    source = WATCHDOG.read_text(encoding="utf-8")
    stage = source.index("reboot_diagnostic_event=")
    shutdown = source.index("& shutdown.exe /r /t 60")
    record = source.index("# 4. record")
    assert stage < shutdown < record
    assert "resource_snapshot" in source
    assert "Never persist command lines" in source


def test_watchdog_uses_same_multisymbol_registry_as_worker() -> None:
    source = WATCHDOG.read_text(encoding="utf-8")
    assert 'multisym_registry = r"D:/QM/strategy_farm/state/multisymbol_eas.txt"' in source
    assert "def is_multisym(ea_id, symbol, payload):" in source
    assert 'multisym = is_multisym(row["ea_id"], row["symbol"], payload)' in source


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_windows_powershell_parses_installers_and_watchdog() -> None:
    paths = ",".join(f"'{path}'" for path in (INSTALLER, WATCHDOG))
    parser = (
        "$failed=$false;"
        f"foreach($path in @({paths})){{"
        "$tokens=$null;$errors=$null;"
        "[System.Management.Automation.Language.Parser]::ParseFile($path,"
        "[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count){$failed=$true;$errors|ForEach-Object{Write-Error $_}}};"
        "if($failed){exit 1}"
    )
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", parser),
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_task_contract_is_delayed_system_startup_and_safe_noop() -> None:
    installer = INSTALLER.read_text(encoding="ascii")
    wrapper = WRAPPER.read_text(encoding="utf-8")
    assert "New-ScheduledTaskTrigger -AtStartup" in installer
    assert '$trigger.Delay = "PT${DelayMinutes}M"' in installer
    assert '-UserId "SYSTEM"' in installer
    assert "-LogonType ServiceAccount" in installer
    assert "-MultipleInstances IgnoreNew" in installer
    assert "-RestartCount 6" in installer
    assert "-RestartInterval (New-TimeSpan -Minutes 5)" in installer
    assert "--initialize-current-boot" in installer
    assert "different boot is then reportable" in installer
    assert "run_reboot_diagnostic_mail_task.py" not in wrapper
