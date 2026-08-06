from __future__ import annotations

import datetime as dt
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "strategy_farm" / "Morning_Safety_Check.ps1"
BRIEF = ROOT / "tools" / "strategy_farm" / "morning_brief.py"


def test_start_only_static_contract() -> None:
    source = SCRIPT.read_text(encoding="utf-8")
    assert "Start-ScheduledTask" in source
    assert "Start_Live_SessionSupervisor.ps1" not in source
    assert "terminal64.exe" in source  # only in explicit direct-launch refusal/evidence text
    assert "Start-Process" not in source
    assert "Stop-Process" not in source
    assert "Stop-ScheduledTask" not in source
    assert "shutdown.exe" not in source
    assert "AutoTrading is never changed" in source
    assert "LIVE_UPTIME_MAINTENANCE.flag" in source
    assert "FACTORY_OFF.flag" in source
    assert "[ValidateRange(1, 336)][int]$MaxNewsAgeHours = 336" in source
    assert "factory_process_scope.ps1" in source
    assert "recovery_task_contract_ready" in source
    assert "live_alarm_mailer.py" in source


def test_installer_manifest_and_0445_contract_are_in_sync() -> None:
    installer = (ROOT / "tools" / "strategy_farm" / "install_live_uptime_tasks.ps1").read_text(encoding="utf-8")
    manifest = (ROOT / "tools" / "strategy_farm" / "qm_tasks.manifest.ps1").read_text(encoding="utf-8")
    assert "QM_Morning_Safety_Check_0445" in installer
    assert "QM_Morning_Safety_Check_0445" in manifest
    assert "AddHours(4).AddMinutes(45)" in installer
    assert "MSFT_TaskDailyTrigger" in installer
    assert "PT14M" in installer


def _load_brief():
    spec = importlib.util.spec_from_file_location("morning_brief_safety_test", BRIEF)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_morning_brief_consumes_one_summary_line(tmp_path: Path) -> None:
    mb = _load_brief()
    state = tmp_path / "morning_safety_check.json"
    state.write_text(
        json.dumps(
            {
                "generated_utc": "2026-08-06T02:45:00Z",
                "summary": {"ok": 6, "healed": 0, "failed": 1, "suppressed": 0, "total": 7},
                "checks": [{"name": "disk_headroom", "status": "FAILED"}],
            }
        ),
        encoding="utf-8",
    )
    mb.MORNING_SAFETY_STATE = state
    mb._utc_now = lambda: dt.datetime(2026, 8, 6, 4, 0, tzinfo=dt.timezone.utc)
    summary = mb.morning_safety_summary()
    assert summary["label"] == "ROT"
    assert "disk_headroom" in summary["summary"]
