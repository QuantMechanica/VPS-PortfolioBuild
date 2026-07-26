from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
WATCHDOG = REPO / "tools" / "strategy_farm" / "factory_watchdog.ps1"


def test_worker_shortage_uses_interactive_token_launcher_not_interactive_task() -> None:
    source = WATCHDOG.read_text(encoding="utf-8")
    shortage = source[source.index("# FIX 3: PURE WORKER SHORTAGE"):]

    assert "Invoke-InteractiveWorkerDedupe" in shortage
    assert "run_in_console_session.ps1" in source
    assert "Start-ScheduledTask -TaskName 'QM_StrategyFarm_WorkerDedupe'" not in shortage
    assert "if ($targetSession -eq 0)" in source
    assert "$_.SessionId -ne $targetSession" in source
    assert "Remove-Item Env:PYTHONHOME" in source
    assert "Remove-Item Env:PYTHONPATH" in source
    assert "-WaitSeconds 180" in source
    assert "WAIT_EXIT pid=" in source
