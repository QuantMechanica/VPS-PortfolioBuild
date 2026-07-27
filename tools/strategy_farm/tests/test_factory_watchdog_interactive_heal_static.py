from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
WATCHDOG = REPO / "tools" / "strategy_farm" / "factory_watchdog.ps1"
CACHE_PURGE = REPO / "tools" / "strategy_farm" / "tester_cache_purge.ps1"
LAUNCHER = REPO / "tools" / "strategy_farm" / "run_in_console_session.ps1"

# The narrow pattern that mislabelled every successful console-session heal as
# heal_failed and skipped the post-spawn verification (2026-07-27 self-heal fix).
NARROW = r"into (?:interactive )?session (\d+)"
BROAD = r"into (?:\w+ )?session (\d+)"


def test_console_session_evidence_regex_is_not_pinned_to_interactive() -> None:
    # run_in_console_session.ps1 emits "LAUNCHED pid=<n> into console session <sid>".
    launcher_src = LAUNCHER.read_text(encoding="utf-8")
    assert "into console session" in launcher_src
    # Every consumer that parses that evidence line must accept the actual label word.
    for consumer in (WATCHDOG, CACHE_PURGE):
        src = consumer.read_text(encoding="utf-8")
        assert BROAD in src, f"{consumer.name} lost the broadened session-evidence regex"
        assert NARROW not in src, f"{consumer.name} regressed to the interactive-pinned regex"


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
