# QUA-662 serialized recovery step — 2026-05-05T19:17+02:00

## Action taken

- Launched one-symbol recovery for `EURJPY.DWX` on `T4`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols EURJPY.DWX --terminal T4 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Outcome + reconciliation

- Invocation returned without final verdict line and no `EURJPY.DWX` row in `report.csv`.
- Latest run folder created:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_171729`
  - contained `raw\run_01\tester.ini` only (no summary at reconcile time).
- Applied manual reconciliation row:
  - `1003,P2,EURJPY.DWX,T4,INVALID,no_summary_json:rc=0,D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_171729`

## Progress delta

- `report.csv` lines: `27 -> 28`
- Canonical coverage: `18/36 -> 19/36`
- Remaining canonical symbols: `17`

## Next action

- Continue serialized one-symbol recovery on unresolved symbols with the same reconcile guard when row emission is missing.
