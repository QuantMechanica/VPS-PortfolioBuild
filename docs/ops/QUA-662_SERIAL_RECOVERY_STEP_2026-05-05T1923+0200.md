# QUA-662 serialized recovery step — 2026-05-05T19:23+02:00

## Action taken

- Launched one-symbol recovery for `GBPNZD.DWX` on `T1`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols GBPNZD.DWX --terminal T1 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Outcome + reconciliation

- Invocation returned before final verdict output.
- No `GBPNZD.DWX` row emitted automatically.
- Latest run dir used for reconciliation evidence:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172050`
- Appended manual row:
  - `1003,P2,GBPNZD.DWX,T1,INVALID,no_summary_json:rc=1,D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172050`

## Progress delta

- `report.csv` lines: `45 -> 46`
- Canonical coverage: `24/36 -> 25/36`
- Remaining canonical symbols: `11`

## Next action

- Continue serialized unresolved-symbol loop with reconciliation guard until `36/36` canonical coverage is reached.
