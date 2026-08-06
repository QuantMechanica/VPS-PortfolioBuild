from __future__ import annotations

import datetime as dt
import importlib.util
import json
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "live_alarm_mailer.py"
SPEC = importlib.util.spec_from_file_location("live_alarm_mailer", SCRIPT)
assert SPEC and SPEC.loader
mailer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mailer)
UTC = dt.timezone.utc


def _source(*, condition: str = "ok", maintenance: bool = False, recovery_ready=True) -> dict:
    alarm = condition != "ok"
    return {
        "schema_version": 3,
        "generated_utc": "2026-08-06T05:00:00Z",
        "author": "T_Live_Watchdog",
        "watchdog_status": "critical" if alarm else "healthy",
        "maintenance": maintenance,
        "reboot_suppressed": False,
        "recovery_task_contract_ready": recovery_ready,
        "recovery_task_contract_errors": [] if recovery_ready else ["QM_T_Live_AtLogon:allow_demand_start"],
        "any_alarm": alarm,
        "escalation_threshold": 3,
        "sessions": {
            "T_LIVE": {
                "expected_state": "RUNNING",
                "condition": condition,
                "detail": condition,
                "alarm": alarm,
                "since_utc": "2026-08-06T05:00:00Z",
                "identical_failure_cycles": 1 if alarm else 0,
            },
            "FTMO": {
                "expected_state": "RUNNING",
                "condition": "ok",
                "detail": "terminal_running",
                "alarm": False,
                "since_utc": "2026-08-06T05:00:00Z",
                "identical_failure_cycles": 0,
            },
        },
    }


def _run(tmp_path: Path, source: dict, minute: int) -> dict:
    source_path = tmp_path / "fixture_live_alarm_state.json"
    source_path.write_text(json.dumps(source), encoding="utf-8")
    return mailer.process_once(
        alarm_file=source_path,
        consumer_state_file=tmp_path / "consumer.json",
        maintenance_flag=tmp_path / "maintenance.flag",
        log_file=tmp_path / "consumer.jsonl",
        now=dt.datetime(2026, 8, 6, 5, minute, tzinfo=UTC),
        repeat_minutes=30,
        dry_run=True,
    )


def test_transition_escalation_cooldown_and_clear(tmp_path: Path) -> None:
    assert _run(tmp_path, _source(), 0)["decision"] == "NONE"
    assert _run(tmp_path, _source(condition="missing"), 1)["decision"] == "RAISE"
    assert _run(tmp_path, _source(condition="missing"), 2)["decision"] == "NONE"
    assert _run(tmp_path, _source(condition="missing"), 3)["decision"] == "ESCALATION"
    assert _run(tmp_path, _source(condition="missing"), 4)["decision"] == "NONE"
    assert _run(tmp_path, _source(condition="missing"), 32)["decision"] == "NONE"
    assert _run(tmp_path, _source(condition="missing"), 33)["decision"] == "ESCALATION"
    assert _run(tmp_path, _source(), 34)["decision"] == "CLEAR"
    assert _run(tmp_path, _source(), 35)["decision"] == "NONE"


def test_maintenance_does_not_consume_new_alarm_transition(tmp_path: Path) -> None:
    assert _run(tmp_path, _source(), 0)["decision"] == "NONE"
    assert _run(tmp_path, _source(condition="missing", maintenance=True), 1)["decision"] == "SUPPRESSED"
    assert _run(tmp_path, _source(condition="missing"), 2)["decision"] == "RAISE"


def test_maintenance_flag_suppresses_without_touching_watchdog(tmp_path: Path) -> None:
    (tmp_path / "maintenance.flag").write_text("maintenance", encoding="utf-8")
    event = _run(tmp_path, _source(condition="missing"), 1)
    assert event["decision"] == "SUPPRESSED"
    assert "send_result" not in event


def test_recovery_contract_false_is_page_worthy(tmp_path: Path) -> None:
    event = _run(tmp_path, _source(recovery_ready=False), 1)
    assert event["decision"] == "RAISE"
    state = json.loads((tmp_path / "consumer.json").read_text(encoding="utf-8"))
    assert any(item["condition"] == "recovery_blocked" for item in state["active_alerts"])


def test_installer_and_manifest_are_in_sync() -> None:
    root = SCRIPT.parents[2]
    installer = (root / "tools" / "strategy_farm" / "install_live_uptime_tasks.ps1").read_text(encoding="utf-8")
    manifest = (root / "tools" / "strategy_farm" / "qm_tasks.manifest.ps1").read_text(encoding="utf-8")
    assert "QM_Live_AlarmMailer_1min" in installer
    assert "QM_Live_AlarmMailer_1min" in manifest
    assert "pythonw.exe" in installer
    assert "OWNER-ratified" in installer


def test_watchdog_producer_exports_recovery_contract() -> None:
    root = SCRIPT.parents[2]
    helper = (root / "tools" / "strategy_farm" / "Live_Alarm_State.ps1").read_text(encoding="utf-8")
    watchdog = (root / "tools" / "strategy_farm" / "T_Live_Watchdog.ps1").read_text(encoding="utf-8")
    assert "$script:QmLiveAlarmStateVersion = 3" in helper
    assert "recovery_task_contract_ready" in helper
    assert "-RecoveryTaskContractReady ([bool]$recoveryTasks.ready)" in watchdog


def test_morning_safety_failure_pages_once_per_run(tmp_path: Path) -> None:
    state_file = tmp_path / "morning_safety_check.json"
    state_file.write_text(
        json.dumps(
            {
                "generated_utc": "2026-08-06T02:45:00Z",
                "checks": [
                    {"name": "disk_headroom", "status": "FAILED", "detail": "D: 3GB"},
                    {"name": "live_terminals", "status": "OK", "detail": "both running"},
                ],
            }
        ),
        encoding="utf-8",
    )
    kwargs = {
        "safety_state_file": state_file,
        "mail_state_file": tmp_path / "mail_state.json",
        "log_file": tmp_path / "mail.jsonl",
        "now": dt.datetime(2026, 8, 6, 2, 45, tzinfo=UTC),
        "dry_run": True,
    }
    first = mailer.process_morning_safety_once(**kwargs)
    second = mailer.process_morning_safety_once(**kwargs)
    assert first["decision"] == "FAILED_PAGE"
    assert first["send_result"]["dry_run"] is True
    assert second["decision"] == "DUPLICATE_SUPPRESSED"


def test_morning_safety_all_ok_never_mails(tmp_path: Path) -> None:
    state_file = tmp_path / "morning_safety_check.json"
    state_file.write_text(
        json.dumps(
            {
                "generated_utc": "2026-08-06T02:45:00Z",
                "checks": [{"name": "disk_headroom", "status": "OK", "detail": "D: 30GB"}],
            }
        ),
        encoding="utf-8",
    )
    event = mailer.process_morning_safety_once(
        safety_state_file=state_file,
        mail_state_file=tmp_path / "mail_state.json",
        log_file=tmp_path / "mail.jsonl",
        now=dt.datetime(2026, 8, 6, 2, 45, tzinfo=UTC),
        dry_run=True,
    )
    assert event["decision"] == "NONE"
    assert not (tmp_path / "mail_state.json").exists()
