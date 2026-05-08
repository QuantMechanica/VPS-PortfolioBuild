# QUA-662 serialized recovery step — 2026-05-05T19:04+02:00

## Action taken

- Continued one-symbol recovery loop using canonical unresolved symbol list.
- Ran one-off backtest for:
  - `AUDJPY.DWX` on `T4`

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols AUDJPY.DWX --terminal T4 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Outcome

- Failure class:
  - `run_smoke_fail:REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`
- Evidence:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_170420\summary.json`

## Progress delta

- `report.csv` line count:
  - before: `11`
  - after: `12`
- New row appended for `AUDJPY.DWX`.

## Next action

- Continue serialized one-symbol recovery on the next unresolved canonical symbol until 36 symbols are covered.
