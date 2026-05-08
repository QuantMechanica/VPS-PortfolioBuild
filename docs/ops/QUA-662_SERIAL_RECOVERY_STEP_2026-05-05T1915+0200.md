# QUA-662 serialized recovery step — 2026-05-05T19:15+02:00

## Action taken

- Ran one-symbol recovery for `EURCHF.DWX` on `T3`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols EURCHF.DWX --terminal T3 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Run behavior

- Attempt 1: `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS` (retry triggered)
- Attempt 2: `MIN_TRADES_NOT_MET`
- Final row recorded as `FAIL`.

## Evidence

- `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_171450\summary.json`

## Progress delta

- `report.csv` lines: `24 -> 26`
- Canonical coverage: `16/36 -> 17/36`
- Remaining canonical symbols: `19`

## Note

- Background row activity continues; an additional `AUDCAD.DWX` fail row landed in the same window.

## Next action

- Continue serialized one-symbol recovery on unresolved canonical symbols until 36/36 coverage is reached.
