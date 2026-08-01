from __future__ import annotations

import csv
import importlib.util
import sqlite3
import subprocess
import sys
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "mailbox_source_intake.py"
SPEC = importlib.util.spec_from_file_location("mailbox_source_intake_under_test", MODULE_PATH)
assert SPEC and SPEC.loader
mailbox = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mailbox)


FIELDS = [
    "source_mail_uid",
    "url",
    "domain_class",
    "resolved_title",
    "status",
]


def _write_leads(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def _rows(*statuses: str) -> list[dict[str, str]]:
    return [
        {
            "source_mail_uid": str(index),
            "url": f"https://example.com/{index}",
            "domain_class": "other",
            "resolved_title": f"lead {index}",
            "status": status,
        }
        for index, status in enumerate(statuses, 1)
    ]


def _write_source_card(farm_root: Path, source_id: str, url: str) -> Path:
    card = farm_root / "artifacts" / "cards_draft" / "QM5_9999_mailbox-source.md"
    card.parent.mkdir(parents=True, exist_ok=True)
    card.write_text(
        "\n".join(
            [
                "---",
                "ea_id: QM5_9999",
                "slug: mailbox-source",
                "status: draft",
                "g0_status: PENDING",
                f"source_id: {source_id}",
                f'source_uri: "{url}"',
                "---",
                "",
                "# Test card",
            ]
        ),
        encoding="utf-8",
    )
    return card


def test_new_csv_status_overrides_legacy_triage_state(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    _write_leads(leads, _rows("NEW", "REJECTED:no rules"))
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)

    found = mailbox.load_new_leads({"https://example.com/1"})

    assert [row["url"] for row in found] == ["https://example.com/1"]


def test_terminal_status_requires_kind_and_detail() -> None:
    assert mailbox._is_terminal_status("QUALIFIED:source-123")
    assert mailbox._is_terminal_status("REJECTED:no mechanical rules")
    assert mailbox._is_terminal_status("DEFERRED:SOURCE_POLICY")
    assert not mailbox._is_terminal_status("DEFERRED:HANDOFF_FAILED:add-source timeout")
    assert not mailbox._is_terminal_status("DEFERRED:TECHNICAL_RETRY")
    assert not mailbox._is_terminal_status("DEFERRED:FETCH_ERROR")
    assert not mailbox._is_terminal_status("DEFERRED:ACCESS_BLOCKED:HTTP 403")
    assert not mailbox._is_terminal_status("NEW")
    assert not mailbox._is_terminal_status("REJECTED")
    assert not mailbox._is_terminal_status("QUALIFIED:")


def test_qualified_status_requires_matching_factory_source(tmp_path, monkeypatch) -> None:
    db = tmp_path / "farm_state.sqlite"
    monkeypatch.setattr(mailbox, "FARM_DB", db)

    ok, reason = mailbox._terminal_handoff_ok("https://example.com/1", "QUALIFIED:source-1")

    assert ok is False
    assert "database missing" in reason


def test_qualified_status_requires_source_linked_g0_card(tmp_path, monkeypatch) -> None:
    farm_root = tmp_path / "farm"
    db = farm_root / "state" / "farm_state.sqlite"
    db.parent.mkdir(parents=True)
    with sqlite3.connect(db) as conn:
        conn.execute("CREATE TABLE sources (id TEXT PRIMARY KEY, uri TEXT)")
        conn.execute(
            "INSERT INTO sources (id, uri) VALUES (?, ?)",
            ("source-1", "https://example.com/1"),
        )
    monkeypatch.setattr(mailbox, "FARM_ROOT", farm_root)
    monkeypatch.setattr(mailbox, "FARM_DB", db)

    ok, reason = mailbox._terminal_handoff_ok(
        "https://example.com/1", "QUALIFIED:source-1"
    )

    assert ok is False
    assert "no valid source-linked G0 card" in reason


def test_qualified_status_accepts_verified_source_and_g0_card(tmp_path, monkeypatch) -> None:
    farm_root = tmp_path / "farm"
    db = farm_root / "state" / "farm_state.sqlite"
    db.parent.mkdir(parents=True)
    with sqlite3.connect(db) as conn:
        conn.execute("CREATE TABLE sources (id TEXT PRIMARY KEY, uri TEXT)")
        conn.execute(
            "INSERT INTO sources (id, uri) VALUES (?, ?)",
            ("source-1", "https://example.com/1"),
        )
    _write_source_card(farm_root, "source-1", "https://example.com/1")
    monkeypatch.setattr(mailbox, "FARM_ROOT", farm_root)
    monkeypatch.setattr(mailbox, "FARM_DB", db)

    ok, reason = mailbox._terminal_handoff_ok(
        "https://example.com/1", "QUALIFIED:source-1"
    )

    assert ok is True
    assert reason is None


def test_large_error_log_does_not_turn_nonzero_codex_green(tmp_path, monkeypatch) -> None:
    codex = tmp_path / "codex.cmd"
    codex.write_text("@exit /b 1", encoding="utf-8")
    prompt_dir = tmp_path / "prompts"
    monkeypatch.setattr(mailbox, "CODEX_CMD", str(codex))
    monkeypatch.setattr(mailbox, "PROMPT_OUT_DIR", prompt_dir)
    monkeypatch.setattr(mailbox, "FARM_ROOT", tmp_path / "farm")
    monkeypatch.setattr(mailbox, "active_managed_codex_count", lambda root: 0)
    monkeypatch.setattr(mailbox, "release_managed_codex_process", lambda *args, **kwargs: 1)

    class FakeProcess:
        pid = 123

        @staticmethod
        def wait(timeout):
            assert timeout == mailbox.ANALYST_CHUNK_TIMEOUT_SECONDS
            return 1

        @staticmethod
        def poll():
            return 1

    def fake_spawn(*args, **kwargs):
        kwargs["stdout"].write(("401 Unauthorized\n" * 1000).encode())
        kwargs["stdout"].flush()
        assert kwargs["env"]["CODEX_HOME"] == mailbox.CODEX_HOME
        assert kwargs["env"]["QM_AGENT_ID"] == "codex"
        return FakeProcess(), {"lease_id": "lease-1"}

    monkeypatch.setattr(mailbox, "spawn_managed_codex", fake_spawn)
    result = mailbox.dispatch_analyst("test prompt")

    assert result["dispatched"] is True
    assert result["ok"] is False
    assert result["returncode"] == 1


def test_timeout_is_failure(tmp_path, monkeypatch) -> None:
    codex = tmp_path / "codex.cmd"
    codex.write_text("@exit /b 0", encoding="utf-8")
    monkeypatch.setattr(mailbox, "CODEX_CMD", str(codex))
    monkeypatch.setattr(mailbox, "PROMPT_OUT_DIR", tmp_path / "prompts")
    monkeypatch.setattr(mailbox, "FARM_ROOT", tmp_path / "farm")
    monkeypatch.setattr(mailbox, "active_managed_codex_count", lambda root: 0)
    monkeypatch.setattr(
        mailbox,
        "terminate_managed_codex_pid",
        lambda root, pid: {"stopped": True, "pid": pid},
    )

    class FakeProcess:
        pid = 456
        exited = False

        @classmethod
        def wait(cls, timeout):
            if timeout == mailbox.ANALYST_CHUNK_TIMEOUT_SECONDS:
                raise subprocess.TimeoutExpired(cmd=["codex"], timeout=timeout)
            cls.exited = True
            return -9

        @classmethod
        def poll(cls):
            return -9 if cls.exited else None

    monkeypatch.setattr(
        mailbox,
        "spawn_managed_codex",
        lambda *args, **kwargs: (FakeProcess(), {"lease_id": "lease-timeout"}),
    )
    result = mailbox.dispatch_analyst("test prompt")

    assert result["ok"] is False
    assert result["returncode"] == 124
    assert result["termination"]["stopped"] is True
    assert result["termination"]["exit_confirmed"] is True


def test_timeout_reports_unconfirmed_termination(tmp_path, monkeypatch) -> None:
    codex = tmp_path / "codex.cmd"
    codex.write_text("@exit /b 0", encoding="utf-8")
    monkeypatch.setattr(mailbox, "CODEX_CMD", str(codex))
    monkeypatch.setattr(mailbox, "PROMPT_OUT_DIR", tmp_path / "prompts")
    monkeypatch.setattr(mailbox, "FARM_ROOT", tmp_path / "farm")
    monkeypatch.setattr(mailbox, "active_managed_codex_count", lambda root: 0)
    monkeypatch.setattr(
        mailbox,
        "terminate_managed_codex_pid",
        lambda root, pid: {"stopped": False, "reason": "cleanup failed", "pid": pid},
    )

    class FakeProcess:
        pid = 654

        @staticmethod
        def wait(timeout):
            raise subprocess.TimeoutExpired(cmd=["codex"], timeout=timeout)

        @staticmethod
        def poll():
            return None

    monkeypatch.setattr(
        mailbox,
        "spawn_managed_codex",
        lambda *args, **kwargs: (FakeProcess(), {"lease_id": "lease-timeout-failed"}),
    )

    result = mailbox.dispatch_analyst("test prompt")

    assert result["ok"] is False
    assert result["termination"]["stopped"] is False
    assert result["termination"]["exit_confirmed"] is False


def test_unexpected_wait_error_terminates_live_managed_process(tmp_path, monkeypatch) -> None:
    codex = tmp_path / "codex.cmd"
    codex.write_text("@exit /b 0", encoding="utf-8")
    monkeypatch.setattr(mailbox, "CODEX_CMD", str(codex))
    monkeypatch.setattr(mailbox, "PROMPT_OUT_DIR", tmp_path / "prompts")
    monkeypatch.setattr(mailbox, "FARM_ROOT", tmp_path / "farm")
    monkeypatch.setattr(mailbox, "active_managed_codex_count", lambda root: 0)
    stopped: list[int] = []
    monkeypatch.setattr(
        mailbox,
        "terminate_managed_codex_pid",
        lambda root, pid: stopped.append(pid) or {"stopped": True, "pid": pid},
    )

    class FakeProcess:
        pid = 789
        exited = False

        @classmethod
        def wait(cls, timeout):
            if timeout == mailbox.ANALYST_CHUNK_TIMEOUT_SECONDS:
                raise OSError("wait failed")
            cls.exited = True
            return -9

        @classmethod
        def poll(cls):
            return -9 if cls.exited else None

    monkeypatch.setattr(
        mailbox,
        "spawn_managed_codex",
        lambda *args, **kwargs: (FakeProcess(), {"lease_id": "lease-error"}),
    )

    result = mailbox.dispatch_analyst("test prompt")

    assert result["ok"] is False
    assert result["cleanup"]["stopped"] is True
    assert stopped == [789]


def test_active_managed_codex_defers_without_dispatch(tmp_path, monkeypatch) -> None:
    codex = tmp_path / "codex.cmd"
    codex.write_text("@exit /b 0", encoding="utf-8")
    monkeypatch.setattr(mailbox, "CODEX_CMD", str(codex))
    monkeypatch.setattr(mailbox, "FARM_ROOT", tmp_path / "farm")
    monkeypatch.setattr(mailbox, "_managed_codex_limit", lambda: 3)
    monkeypatch.setattr(mailbox, "active_managed_codex_count", lambda root: 3)
    monkeypatch.setattr(
        mailbox,
        "spawn_managed_codex",
        lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("must not spawn")),
    )

    result = mailbox.dispatch_analyst("test prompt")

    assert result["dispatched"] is False
    assert result["ok"] is False
    assert "capacity full" in result["reason"]


def test_low_token_flag_reduces_managed_capacity_to_one(tmp_path, monkeypatch) -> None:
    farm_root = tmp_path / "farm"
    farm_root.mkdir()
    (farm_root / "CODEX_LOW_TOKENS.flag").write_text("managed", encoding="utf-8")
    monkeypatch.setattr(mailbox, "FARM_ROOT", farm_root)

    assert mailbox._managed_codex_limit() == 1


def test_handoff_failure_status_remains_retryable(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    _write_leads(
        leads,
        _rows(
            "DEFERRED:HANDOFF_FAILED:add-source timeout",
            "DEFERRED:SOURCE_POLICY",
            "DEFERRED:FETCH_ERROR",
        ),
    )
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)

    found = mailbox.load_new_leads()

    assert [row["url"] for row in found] == [
        "https://example.com/1",
        "https://example.com/3",
    ]


def test_56_lead_backlog_chunks_into_five_tens_and_six() -> None:
    leads = [{"url": f"https://example.com/{index}"} for index in range(56)]

    chunks = mailbox._chunk_leads(leads)

    assert [len(chunk) for chunk in chunks] == [10, 10, 10, 10, 10, 6]
    assert [row for chunk in chunks for row in chunk] == leads


def test_sequential_chunks_checkpoint_terminal_progress(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    rows = _rows(*(["NEW"] * 12))
    _write_leads(leads, rows)
    built_chunks: list[list[dict[str, str]]] = []
    dispatched_urls: list[list[str]] = []
    audit_snapshots: list[set[str]] = []
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)
    monkeypatch.setattr(mailbox, "run_sweep", lambda dry: {"ok": True, "returncode": 0})
    monkeypatch.setattr(mailbox.time, "monotonic", lambda: 0.0)
    monkeypatch.setattr(mailbox, "_save_triaged", lambda urls: audit_snapshots.append(set(urls)))
    monkeypatch.setattr(mailbox, "_log_run", lambda rec: None)
    monkeypatch.setattr(sys, "argv", ["mailbox_source_intake.py"])

    def fake_build_prompt(current: list[dict]) -> str:
        built_chunks.append(list(current))
        return f"chunk-{len(built_chunks)}"

    def fake_dispatch(prompt: str) -> dict:
        chunk = built_chunks[len(dispatched_urls)]
        urls = [row["url"] for row in chunk]
        dispatched_urls.append(urls)
        for row in rows:
            if row["url"] in urls:
                row["status"] = "REJECTED:no mechanical rules"
        _write_leads(leads, rows)
        return {"dispatched": True, "ok": True, "returncode": 0, "prompt": prompt}

    monkeypatch.setattr(mailbox, "build_prompt", fake_build_prompt)
    monkeypatch.setattr(mailbox, "dispatch_analyst", fake_dispatch)

    assert mailbox.main() == 0
    assert [len(urls) for urls in dispatched_urls] == [10, 2]
    assert audit_snapshots[0] == set(dispatched_urls[0])
    assert audit_snapshots[1] == set(dispatched_urls[0] + dispatched_urls[1])
    assert mailbox.load_new_leads() == []


def test_runtime_early_stop_leaves_unattempted_chunk_retryable(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    rows = _rows(*(["NEW"] * 12))
    _write_leads(leads, rows)
    clock = iter([0.0, 0.0, 100.0])
    dispatch_calls: list[str] = []
    logged: list[dict] = []
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)
    monkeypatch.setattr(mailbox, "RUN_BUDGET_SECONDS", 200)
    monkeypatch.setattr(mailbox, "ANALYST_CHUNK_TIMEOUT_SECONDS", 100)
    monkeypatch.setattr(mailbox, "SHUTDOWN_GRACE_SECONDS", 50)
    monkeypatch.setattr(mailbox.time, "monotonic", lambda: next(clock))
    monkeypatch.setattr(mailbox, "run_sweep", lambda dry: {"ok": True, "returncode": 0})
    monkeypatch.setattr(mailbox, "build_prompt", lambda current: "prompt")
    monkeypatch.setattr(mailbox, "_save_triaged", lambda urls: None)
    monkeypatch.setattr(mailbox, "_log_run", lambda rec: logged.append(dict(rec)))
    monkeypatch.setattr(sys, "argv", ["mailbox_source_intake.py"])

    def fake_dispatch(prompt: str) -> dict:
        dispatch_calls.append(prompt)
        for row in rows[:10]:
            row["status"] = "REJECTED:no mechanical rules"
        _write_leads(leads, rows)
        return {"dispatched": True, "ok": True, "returncode": 0}

    monkeypatch.setattr(mailbox, "dispatch_analyst", fake_dispatch)

    assert mailbox.main() == 1
    assert len(dispatch_calls) == 1
    assert [row["url"] for row in mailbox.load_new_leads()] == [
        "https://example.com/11",
        "https://example.com/12",
    ]
    early_stop = [entry for entry in logged if entry.get("event") == "analyst_early_stop"]
    assert early_stop[-1]["next_chunk"] == 2
    assert early_stop[-1]["chunks_remaining"] == 1


def test_partial_analyst_result_keeps_new_lead_retryable(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    rows = _rows("NEW", "NEW")
    _write_leads(leads, rows)
    saved: list[set[str]] = []
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)
    monkeypatch.setattr(mailbox, "run_sweep", lambda dry: {"ok": True, "returncode": 0})
    monkeypatch.setattr(mailbox, "build_prompt", lambda current: "prompt")
    monkeypatch.setattr(mailbox, "_load_triaged", lambda: {"https://example.com/2"})
    monkeypatch.setattr(mailbox, "_save_triaged", lambda urls: saved.append(set(urls)))
    monkeypatch.setattr(mailbox, "_log_run", lambda rec: None)
    monkeypatch.setattr(sys, "argv", ["mailbox_source_intake.py"])

    def fake_dispatch(prompt: str) -> dict:
        rows[0]["status"] = "REJECTED:no mechanical rules"
        _write_leads(leads, rows)
        return {"dispatched": True, "ok": True, "returncode": 0}

    monkeypatch.setattr(mailbox, "dispatch_analyst", fake_dispatch)

    assert mailbox.main() == 1
    assert saved[-1] == {"https://example.com/1"}
    assert [row["url"] for row in mailbox.load_new_leads()] == ["https://example.com/2"]


def test_all_terminal_results_complete_successfully(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    rows = _rows("NEW", "NEW")
    _write_leads(leads, rows)
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)
    monkeypatch.setattr(mailbox, "run_sweep", lambda dry: {"ok": True, "returncode": 0})
    monkeypatch.setattr(mailbox, "build_prompt", lambda current: "prompt")
    monkeypatch.setattr(mailbox, "_load_triaged", set)
    monkeypatch.setattr(mailbox, "_save_triaged", lambda urls: None)
    monkeypatch.setattr(mailbox, "_log_run", lambda rec: None)
    monkeypatch.setattr(sys, "argv", ["mailbox_source_intake.py"])

    def fake_dispatch(prompt: str) -> dict:
        rows[0]["status"] = "REJECTED:no rules"
        rows[1]["status"] = "DEFERRED:SOURCE_POLICY"
        _write_leads(leads, rows)
        return {"dispatched": True, "ok": True, "returncode": 0}

    monkeypatch.setattr(mailbox, "dispatch_analyst", fake_dispatch)

    assert mailbox.main() == 0


def test_verified_terminal_results_override_nonzero_cli_warning(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    rows = _rows("NEW")
    _write_leads(leads, rows)
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)
    monkeypatch.setattr(mailbox, "run_sweep", lambda dry: {"ok": True, "returncode": 0})
    monkeypatch.setattr(mailbox, "build_prompt", lambda current: "prompt")
    monkeypatch.setattr(mailbox, "_save_triaged", lambda urls: None)
    monkeypatch.setattr(mailbox, "_log_run", lambda rec: None)
    monkeypatch.setattr(sys, "argv", ["mailbox_source_intake.py"])

    def fake_dispatch(prompt: str) -> dict:
        rows[0]["status"] = "REJECTED:no mechanical rules"
        _write_leads(leads, rows)
        return {"dispatched": True, "ok": False, "returncode": 1}

    monkeypatch.setattr(mailbox, "dispatch_analyst", fake_dispatch)

    assert mailbox.main() == 0


def test_failed_sweep_is_visible_even_when_there_are_no_leads(tmp_path, monkeypatch) -> None:
    leads = tmp_path / "leads.csv"
    _write_leads(leads, _rows("REJECTED:no rules"))
    monkeypatch.setattr(mailbox, "LEADS_CSV", leads)
    monkeypatch.setattr(mailbox, "run_sweep", lambda dry: {"ok": False, "returncode": 1})
    monkeypatch.setattr(mailbox, "_load_triaged", set)
    monkeypatch.setattr(mailbox, "_log_run", lambda rec: None)
    monkeypatch.setattr(sys, "argv", ["mailbox_source_intake.py"])

    assert mailbox.main() == 1


def test_unreadable_leads_csv_is_not_a_false_green(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(mailbox, "LEADS_CSV", tmp_path)
    monkeypatch.setattr(mailbox, "run_sweep", lambda dry: {"ok": True, "returncode": 0})
    monkeypatch.setattr(mailbox, "_log_run", lambda rec: None)
    monkeypatch.setattr(sys, "argv", ["mailbox_source_intake.py"])

    assert mailbox.main() == 2


def test_pythonw_excepthook_persists_uncaught_traceback(tmp_path, monkeypatch) -> None:
    crash_log = tmp_path / "mailbox_pythonw_crash.log"
    monkeypatch.setattr(mailbox, "PYTHONW_CRASH_LOG", crash_log)
    try:
        raise RuntimeError("mailbox-hook-probe")
    except RuntimeError:
        exc_type, exc, tb = sys.exc_info()
        assert exc_type is not None and exc is not None
        mailbox._pythonw_excepthook(exc_type, exc, tb)

    text = crash_log.read_text(encoding="utf-8")
    assert "uncaught top-level exception" in text
    assert "RuntimeError: mailbox-hook-probe" in text


def test_task_contract_uses_mnt003_console_bridge_and_stays_retrying() -> None:
    repo = MODULE_PATH.parents[2]
    installer = (repo / "tools" / "strategy_farm" / "install_mailbox_source_intake_task.ps1").read_text(
        encoding="utf-8"
    )
    manifest = (repo / "tools" / "strategy_farm" / "qm_tasks.manifest.ps1").read_text(encoding="utf-8")

    assert "New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount" in installer
    assert "[string]$UserId = 'qm-admin'" in installer
    assert "run_in_console_session.ps1" in installer
    assert '-TargetUser "{4}"' in installer
    assert "-WaitSeconds 2640" in installer
    assert "-RestartCount 4" in installer
    assert "-ExecutionTimeLimit (New-TimeSpan -Minutes 45)" in installer
    assert "-At 06:07" in installer
    always_on = manifest.split("$QM_ALWAYSON_TASKS", 1)[1].split("$QM_ENFORCE_DISABLED_TASKS", 1)[0]
    assert "QM_StrategyFarm_MailboxSourceIntake_Daily" in always_on


def test_prompt_requires_idempotent_source_card_and_reservation_resume() -> None:
    prompt = (MODULE_PATH.parent / "prompts" / "mailbox_source_intake_prompt.md").read_text(
        encoding="utf-8"
    )

    assert "sources.uri == <exact URL>" in prompt
    assert "mailbox-<first 16 lowercase hex chars of SHA-256(exact URL)>" in prompt
    assert "Never\n     choose a new slug on retry" in prompt
    assert "Reuse its\n     EA ID only when `strategy_id == source_id`" in prompt
