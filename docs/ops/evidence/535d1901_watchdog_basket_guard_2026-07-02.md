# Watchdog Basket/Cold-Cache Guard - 2026-07-02

Task: `535d1901-b96b-453c-aac6-2ad37f5bd4d0`

## Scope

Fixed the live scheduled-task code paths in `C:\QM\repo`:

- `tools/strategy_farm/factory_watchdog.ps1`
- `tools/strategy_farm/tester_cache_purge.ps1`
- `tools/strategy_farm/terminal_worker.py`
- `tools/strategy_farm/farmctl.py`
- `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`

## Changes

- Watchdog now probes active work_items and recent log/report/journal mtimes.
- Real-stall full reset is suppressed when an active basket/multisymbol work_item exists, or when active run evidence has progressed in the last 10 minutes.
- Worker-shortage/dispatch-stall FactoryON reset is also deferred while an active basket/multisymbol work_item is protected.
- Watchdog JSONL now records active multisymbol and active progress counts.
- Tester cache purge now pauses new dispatch, protects terminals with active work_items or running `terminal64.exe`, and purges only idle terminal caches.
- Purge trim logic preserves protected active terminal workers.
- Terminal worker and farmctl summary discovery now reject stale `summary.json` / `aggregate.json` evidence whose run tag predates the current claim/start time; fallback is file mtime for summaries without a run tag.
- Added tests for rejecting an old run-tag summary even when its mtime is fresh, and accepting a current run-tag summary.

## Verification

Passed:

- `python -m unittest tools.strategy_farm.tests.test_terminal_worker_atomic_claim`
- `python -m py_compile C:\QM\repo\tools\strategy_farm\terminal_worker.py C:\QM\repo\tools\strategy_farm\farmctl.py`
- PowerShell parser check for `factory_watchdog.ps1`
- PowerShell parser check for `tester_cache_purge.ps1`
- Inline farmctl freshness helper check

Non-destructive dry-run check:

- `tester_cache_purge.ps1 -LowWaterGB 1000 -DryRun` correctly reported protected active/running terminals and idle-only purge intent.
- The two dry-run log lines were removed afterward so watchdog `recentPurge` logic was not polluted.

No terminal was started manually. `T_Live` and AutoTrading were not touched.
