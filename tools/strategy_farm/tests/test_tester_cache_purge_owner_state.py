from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "strategy_farm" / "tester_cache_purge.ps1"


@pytest.mark.skipif(os.name != "nt", reason="Windows PowerShell 5.1 only")
def test_tester_cache_purge_parses_in_windows_powershell_51() -> None:
    command = (
        "$tokens=$null;$errors=$null;"
        f"[Management.Automation.Language.Parser]::ParseFile('{SCRIPT}',"
        "[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count){$errors|ForEach-Object{Write-Error $_};exit 1}"
    )
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command),
        cwd=ROOT, capture_output=True, text=True, timeout=20, check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_purge_preserves_factory_owner_state_before_interactive_restart() -> None:
    source = SCRIPT.read_text(encoding="utf-8")
    guard = source.index("if (-not $factoryRestartAuthorized)")
    start = source.index("$launchEvidence = Invoke-InteractiveWorkerDedupe")
    assert guard < start
    assert "$factoryOffWasPresent" in source
    assert "$pumpWasEnabled -or $tickWasEnabled" in source
    assert "factory restart SKIPPED: captured OWNER state was OFF" in source
    assert "QM_StrategyFarm_FactoryON_AtLogon" not in source
    assert "run_in_console_session.ps1" in source
    assert "start_terminal_workers.py" in source
    assert "--dedupe" in source
    assert "Start-ScheduledTask -TaskName $dedupeTask.TaskName" not in source
    assert "QM_StrategyFarm_WorkerDedupe" not in source
