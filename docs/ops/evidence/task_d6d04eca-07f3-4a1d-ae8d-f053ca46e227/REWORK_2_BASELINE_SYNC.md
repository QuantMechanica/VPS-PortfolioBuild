# task d6d04eca — rework 2 baseline sync

Lane `agents/claude-orchestration-2` (claim base `c1cb301ee89a9e7c3fa540bed0f2d35d368dbb94`) is diverged from canonical
`agents/board-advisor`. This commit sets the 12 rework-touched code/test paths to their exact
canonical content at `9d629b26752159219695a53c0858f42ec5841fda` so the following fix commit's diff is canonical -> canonical+fix
and cherry-picks cleanly onto canonical. Cherry-picked onto canonical, only this note changes.

Paths:
- `framework/scripts/mt5_diagnostics/dwx_2026_band_a_export.py`
- `tools/strategy_farm/factory_watchdog.ps1`
- `tools/strategy_farm/interactive_worker_keeper.py`
- `tools/strategy_farm/reload_idle_workers.py`
- `tools/strategy_farm/start_terminal_workers.ps1`
- `tools/strategy_farm/start_terminal_workers.py`
- `tools/strategy_farm/tests/test_dwx_2026_band_a_export.py`
- `tools/strategy_farm/tests/test_factory_canary_fleet.py`
- `tools/strategy_farm/tests/test_factory_watchdog_interactive_heal_static.py`
- `tools/strategy_farm/tests/test_factory_watchdog_reservation_reset_guard.py`
- `tools/strategy_farm/tests/test_start_terminal_workers_env.py`
- `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`
