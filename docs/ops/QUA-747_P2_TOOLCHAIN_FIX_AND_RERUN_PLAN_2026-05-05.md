# QUA-747 P2 Toolchain Fix + Re-run Plan (2026-05-05)

## Root Cause (confirmed)

`framework/scripts/p2_baseline.py` was bypassing dispatcher capacity controls by:
- pinning terminals directly (previous default round-robin `T1..T5`), and
- always forcing `-AllowRunningTerminal` in `run_smoke.ps1` invocations.

This allowed overlapping MT5 usage under multi-EA P2 execution and matches the modal stack:
- `REPORT_MISSING`
- `METATESTER_HUNG`
- `INCOMPLETE_RUNS`

## Fix Landed

Commit: `f448bbea9fd4f8ba1f8c45bb22544581f4f4f95c`

Changed files:
- `framework/scripts/p2_baseline.py`
  - default dispatch target now `terminal=any` when `--terminal` is not provided.
  - `-AllowRunningTerminal` is no longer forced; now opt-in via `--allow-running-terminal`.
- `framework/scripts/tests/test_p2_baseline.py`
  - unit guard ensures `invoke_run_smoke(...)` does not force `-AllowRunningTerminal` by default and supports `terminal=any`.

## Verification Evidence

- `python -m unittest framework.scripts.tests.test_p2_baseline` -> PASS
- `python -m unittest framework.scripts.tests.test_resolve_backtest_target` -> PASS
- Dry-run dispatch behavior:
  - `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols EURUSD.DWX,GBPUSD.DWX --dry-run`
  - output confirms `EURUSD.DWX -> any`, `GBPUSD.DWX -> any`

## Re-run Plan

1. QM5_1003 resume only failed symbols (6)
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols AUDCAD.DWX,EURAUD.DWX,GBPAUD.DWX,NDXm.DWX,NZDCAD.DWX,USDCHF.DWX --year 2024 --runs 2 --min-trades 20 --resume`

2. QM5_1004 fresh full baseline
- `python framework/scripts/p2_baseline.py --ea QM5_1004 --year 2024 --runs 2 --min-trades 20`

3. QM5_SRC04_S03 fresh full baseline (after 1004 clear)
- `python framework/scripts/p2_baseline.py --ea QM5_SRC04_S03 --year 2024 --runs 2 --min-trades 20`

## Success Gate for QUA-747 Closure

- Aggregate NO_REPORT-class modal (`REPORT_MISSING`/`METATESTER_HUNG`/`INCOMPLETE_RUNS`) under 5% across 108 total symbol runs (36 x 3 EAs).
- Any residual failures must show symbol- or strategy-specific causes, not universal infra modal.