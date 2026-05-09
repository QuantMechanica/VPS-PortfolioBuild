# QUA-971 Setfile Correction Evidence (2026-05-08)

## Scope
- Issue: [QUA-971](/QUA/issues/QUA-971)
- EA: `QM5_1003_davey_baseline_3bar`
- Symbol focus: `EURUSD.DWX`

## Changes Applied
- Patched generator: `framework/scripts/gen_setfile.ps1`
  - Added compatibility mapping for `QM5_1003_davey_baseline_3bar`:
    - `ssl` -> `ssl_usd_cap`
    - `ATR_period` -> `strategy_atr_period`
    - drops `nContracts` (not an EA input)
- Regenerated H1 backtest setfile pack for all existing QM5_1003 symbols.

## Corrected EURUSD setfile
- Path: `C:\QM\repo\framework\EAs\QM5_1003_davey_baseline_3bar\sets\QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set`
- Contents now include:
  - `ssl1=0.75`
  - `ssl_usd_cap=2000`
  - `strategy_atr_period=14`

## Validation Run (targeted P2 rerun)
- Command:
  - `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols EURUSD.DWX --year 2024 --period H1`
- New evidence summary:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260508_201536\summary.json`
- Observed result:
  - `FAIL`
  - reason classes: `REPORT_MISSING`, `METATESTER_HUNG`, `INCOMPLETE_RUNS`

## Interpretation
- The prior EURUSD failure class `NO_REAL_TICKS_MARKER` is not present in this corrected rerun summary.
- The current blocker is tester/runtime export stability (`REPORT_MISSING` + `METATESTER_HUNG`), not setfile token mismatch.

## Next Action
- CTO + Pipeline/Ops rerun EURUSD on a healthy terminal/runtime lane, then append refreshed `report.csv` row and summary evidence for QUA-971 closure.
