# QUA-662 serialized recovery step — 2026-05-05T19:21+02:00

## Action taken

- Launched one-symbol recovery for `GBPCHF.DWX` on `T4`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols GBPCHF.DWX --terminal T4 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Outcome + reconciliation

- Invocation returned before final verdict output; no `GBPCHF.DWX` row was emitted automatically.
- Latest run directory:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172143`
- Appended manual row:
  - `1003,P2,GBPCHF.DWX,T4,INVALID,no_summary_json:rc=1,D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172143`

## Progress delta

- `report.csv` lines: `43 -> 44`
- Canonical coverage: `22/36 -> 23/36`
- Remaining canonical symbols: `13`

## Next action

- Continue serialized unresolved-symbol loop with same reconciliation guard until canonical coverage reaches `36/36`.
