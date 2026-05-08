# QUA-662 serialized recovery step — 2026-05-05T19:22+02:00

## Action taken

- Launched one-symbol recovery for `GBPJPY.DWX` on `T5`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols GBPJPY.DWX --terminal T5 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Outcome + reconciliation

- Invocation returned before final verdict output.
- No `GBPJPY.DWX` row was auto-emitted.
- Latest run dir:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172221`
- Appended manual row:
  - `1003,P2,GBPJPY.DWX,T5,INVALID,no_summary_json:rc=1,D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172221`

## Progress delta

- `report.csv` lines: `44 -> 45`
- Canonical coverage: `23/36 -> 24/36`
- Remaining canonical symbols: `12`

## Next action

- Continue serialized unresolved-symbol loop with reconciliation guard until `36/36` canonical coverage is reached.
