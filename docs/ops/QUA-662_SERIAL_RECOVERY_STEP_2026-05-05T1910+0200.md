# QUA-662 serialized recovery step — 2026-05-05T19:10+02:00

## Action taken

- Executed one-symbol recovery for:
  - `CADCHF.DWX` on `T3`

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols CADCHF.DWX --terminal T3 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Direct outcome

- Failure class:
  - `run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS`
- Evidence:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_171017\summary.json`

## Coverage delta

- `report.csv` line count:
  - before: `19`
  - after: `21`
- Canonical symbol coverage:
  - before: `12/36`
  - after: `14/36`
- Remaining canonical symbols: `22`

## Note

- Asynchronous/background rows continue to appear between snapshots (e.g., `CHFJPY.DWX` row landed during this step).

## Next action

- Continue serialized one-symbol recovery with pre/post snapshots until canonical coverage reaches 36/36.
