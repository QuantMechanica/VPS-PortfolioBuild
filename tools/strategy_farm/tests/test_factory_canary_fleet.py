from __future__ import annotations

from pathlib import Path

from tools.strategy_farm import farmctl, health, start_terminal_workers


REPO = Path(__file__).resolve().parents[3]


def test_python_factory_surfaces_share_twelve_slot_identity() -> None:
    expected = tuple(f"T{i}" for i in range(1, 13))
    assert farmctl.MT5_TERMINALS == expected
    assert start_terminal_workers.TERMINALS == expected
    assert health.FACTORY_TERMINALS == expected
    assert farmctl.is_factory_terminal_name("T11")
    assert farmctl.is_factory_terminal_name("T12")
    assert not farmctl.is_factory_terminal_name("T13")


def test_powershell_worker_and_watchdog_derive_ten_active_from_two_inert() -> None:
    launcher = (REPO / "tools/strategy_farm/start_terminal_workers.ps1").read_text(
        encoding="utf-8-sig"
    )
    watchdog = (REPO / "tools/strategy_farm/factory_watchdog.ps1").read_text(
        encoding="utf-8-sig"
    )
    factory_on = (REPO / "tools/strategy_farm/Factory_ON.ps1").read_text(
        encoding="utf-8-sig"
    )
    assert "$factoryTerminals = 1..12" in launcher
    assert "$ExpectWorkers = [math]::Max(1, 12 - $disabledCount)" in watchdog
    assert "$QM_OWNER_APPROVED_DISABLED_TERMINALS = @(\n    'T11','T12'" in factory_on
    assert "$derivedWorkerTerminals = @(1..12" in factory_on


def test_reconcile_and_worker_avoid_sets_cover_canaries() -> None:
    reconcile = (REPO / "framework/scripts/reconcile_dispatch_state.py").read_text(
        encoding="utf-8-sig"
    )
    worker = (REPO / "tools/strategy_farm/terminal_worker.py").read_text(
        encoding="utf-8-sig"
    )
    assert 'FACTORY_TERMINALS = {f"T{i}" for i in range(1, 13)}' in reconcile
    assert worker.count('range(1, 13)') >= 2


def test_run_smoke_any_honors_disabled_canaries() -> None:
    runner = (REPO / "framework/scripts/run_smoke.ps1").read_text(
        encoding="utf-8-sig"
    )
    assert "$disabledPolicy = 'D:\\QM\\strategy_farm\\state\\disabled_terminals.txt'" in runner
    assert "if ($candidate -in $disabled)" in runner
    assert "run_smoke.dispatch_skip_disabled_terminal" in runner
