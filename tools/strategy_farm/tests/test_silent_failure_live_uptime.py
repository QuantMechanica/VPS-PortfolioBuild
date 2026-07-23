from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import silent_failure_monitor as monitor  # noqa: E402


NOW = datetime(2026, 7, 22, 8, 0, tzinfo=timezone.utc)


def _write_state(path: Path, **overrides) -> None:
    state = {
        "last_checked_utc": "2026-07-22T07:59:00Z",
        "status": "healthy",
        "process_probe_ok": True,
        "dxz_running": True,
        "ftmo_running": True,
        "dxz_session_ids": [4],
        "ftmo_session_ids": [4],
        "session_placement_ok": True,
        "session_supervisor_ready": True,
        "session_supervisor_age_seconds": 4,
        "session_supervisor_reason": "ready",
        "maintenance": False,
        "autologon_ready": True,
        "autologon_secret_probe": "present",
        "target_session_id": 4,
        "target_session_state": "Active",
        "dxz_profile": "DarwinexZero_V2_LiveOps",
        "expected_dxz_profile": "DarwinexZero_V2_LiveOps",
        "ftmo_profile": "Default",
        "expected_ftmo_profile": "Default",
        "dxz_experts_enabled": 1,
        "ftmo_experts_enabled": 1,
        "errors": [],
    }
    state.update(overrides)
    path.write_text(json.dumps(state), encoding="utf-8")


def test_live_uptime_is_ok_only_when_both_processes_and_recovery_are_ready(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "live.json"
    _write_state(state_path)
    monkeypatch.setattr(monitor, "LIVE_UPTIME_STATE", state_path)
    monkeypatch.setattr(monitor, "_now", lambda: NOW)

    result = monitor.check_live_uptime()

    assert result[0]["status"] == monitor.OK


def test_live_uptime_fails_when_one_terminal_is_missing(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "live.json"
    _write_state(state_path, ftmo_running=False, status="degraded")
    monkeypatch.setattr(monitor, "LIVE_UPTIME_STATE", state_path)
    monkeypatch.setattr(monitor, "_now", lambda: NOW)

    result = monitor.check_live_uptime()

    assert result[0]["status"] == monitor.FAIL
    assert "FTMO" in result[0]["detail"]


def test_live_uptime_fails_closed_when_process_probe_is_unknown(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "live.json"
    _write_state(state_path, process_probe_ok=False, dxz_running=False, ftmo_running=False)
    monkeypatch.setattr(monitor, "LIVE_UPTIME_STATE", state_path)
    monkeypatch.setattr(monitor, "_now", lambda: NOW)

    result = monitor.check_live_uptime()

    assert result[0]["status"] == monitor.FAIL
    assert "unknown" in result[0]["detail"]


def test_live_uptime_fails_on_profile_drift(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "live.json"
    _write_state(state_path, dxz_profile="DarwinexZero_V1")
    monkeypatch.setattr(monitor, "LIVE_UPTIME_STATE", state_path)
    monkeypatch.setattr(monitor, "_now", lambda: NOW)

    result = monitor.check_live_uptime()

    assert result[0]["name"] == "live_mt5_profile"
    assert result[0]["status"] == monitor.FAIL


def test_live_uptime_fails_when_resident_session_recovery_is_missing(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "live.json"
    _write_state(state_path, session_supervisor_ready=False, session_supervisor_reason="state_stale")
    monkeypatch.setattr(monitor, "LIVE_UPTIME_STATE", state_path)
    monkeypatch.setattr(monitor, "_now", lambda: NOW)

    result = monitor.check_live_uptime()

    assert result[0]["name"] == "live_mt5_session_supervisor"
    assert result[0]["status"] == monitor.FAIL


def test_live_uptime_fails_when_watchdog_state_is_stale(tmp_path, monkeypatch) -> None:
    state_path = tmp_path / "live.json"
    stale = NOW - timedelta(minutes=8)
    _write_state(state_path, last_checked_utc=stale.strftime("%Y-%m-%dT%H:%M:%SZ"))
    monkeypatch.setattr(monitor, "LIVE_UPTIME_STATE", state_path)
    monkeypatch.setattr(monitor, "_now", lambda: NOW)

    result = monitor.check_live_uptime()

    assert result[0]["status"] == monitor.FAIL
    assert "stale" in result[0]["detail"]


def test_live_uptime_missing_state_is_a_hard_failure(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(monitor, "LIVE_UPTIME_STATE", tmp_path / "absent.json")

    result = monitor.check_live_uptime()

    assert result[0]["status"] == monitor.FAIL


def test_logon_only_live_tasks_do_not_alarm_on_historical_demand_refusal() -> None:
    probe = {
        "tasks": [{
            "Name": "QM_T_Live_AtLogon",
            "State": "Ready",
            "LastResult": 2147946720,
            "LastRun": "2026-07-22T05:32:32Z",
            "NextRun": None,
        }],
        "worker_count": 0,
    }

    assert monitor.check_scheduled_tasks(probe) == []
