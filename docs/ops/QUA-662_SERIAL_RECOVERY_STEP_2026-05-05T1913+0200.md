# QUA-662 serialized recovery step — 2026-05-05T19:13+02:00

## Action taken

- Ran one-symbol recovery for `EURCAD.DWX` on `T2`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols EURCAD.DWX --terminal T2 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Run behavior

- Attempt 1: `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS` (triggered one retry)
- Attempt 2: `REPORT_MISSING;INCOMPLETE_RUNS`
- Final verdict row: `FAIL`

## Evidence

- `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_171321\summary.json`

## Progress delta

- `report.csv` lines: `23 -> 24`
- Canonical coverage: `15/36 -> 16/36`
- Remaining canonical symbols: `20`

## Next action

- Continue serialized one-symbol recovery on unresolved canonical symbols until coverage reaches 36/36.
