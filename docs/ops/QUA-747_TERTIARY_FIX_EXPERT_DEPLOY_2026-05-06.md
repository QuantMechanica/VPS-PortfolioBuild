# QUA-747 Tertiary Fix — Expert Binary Deployment (2026-05-06)

## Root Cause

From terminal tester logs (`D:/QM/mt5/T5/Tester/logs/20260505.log`):
- repeated errors: `Experts\\QM\\QM5_1004_davey_es_breakout.ex5 not found`

This caused pre-execution failure and downstream modal stack:
- `REPORT_MISSING`
- `INCOMPLETE_RUNS`

The report/materialization path was not the primary failure point; the EA binary was missing in terminal Expert directories for the routed run.

## Fix

File: `framework/scripts/p2_baseline.py`

- Added `ensure_expert_binary_deployed(ea_dir, terminal_roots)`.
- Before P2 symbol loop, copy `<ea_dir>/<ea_dir.name>.ex5` to each terminal:
  - `D:/QM/mt5/T1..T5/MQL5/Experts/QM/<ea_dir.name>.ex5`
- Fail fast with `[FATAL] missing EA binary ...` if source `.ex5` is absent.

## Tests

File: `framework/scripts/tests/test_p2_baseline.py`

- `test_ensure_expert_binary_deploys_to_all_terminals`
- `test_ensure_expert_binary_deployed_raises_when_source_missing`

Plus regression suite:
- `python -m unittest framework.scripts.tests.test_p2_baseline` -> PASS
- `python -m unittest framework.scripts.tests.test_resolve_backtest_target` -> PASS

## Live Evidence

1. Deployment check via dry-run:
- `python framework/scripts/p2_baseline.py --ea QM5_1004 --symbols AUDNZD.DWX --dry-run`
- Verified present on T1..T5:
  - `D:/QM/mt5/T<N>/MQL5/Experts/QM/QM5_1004_davey_es_breakout.ex5`

2. Execution probe:
- `python framework/scripts/p2_baseline.py --ea QM5_1004 --symbols AUDNZD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120`
- Result changed from infrastructure modal to strategy gate outcome:
  - `[FAIL] ... reason=run_smoke_fail:MIN_TRADES_NOT_MET`
- No `REPORT_MISSING` / `no_summary_json` / wrapper-timeout invalid on this probe.