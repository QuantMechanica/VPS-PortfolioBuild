# QUA-662 serialized recovery step — 2026-05-05T19:24+02:00

## Action taken

- Launched one-symbol recovery for `GBPUSD.DWX` on `T2`.

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols GBPUSD.DWX --terminal T2 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Outcome + reconciliation

- Invocation returned before final verdict output.
- No auto row for `GBPUSD.DWX`.
- Latest run directory used for evidence:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172456`
- Appended manual row:
  - `1003,P2,GBPUSD.DWX,T2,INVALID,no_summary_json:rc=1,D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172456`

## Progress delta

- Background row activity accelerated during this step.
- `report.csv` lines: `46 -> 64`
- Canonical coverage: `25/36 -> 30/36`
- Remaining canonical symbols: `6`
  - `GDAXIm.DWX,NZDCHF.DWX,NZDUSD.DWX,WS30.DWX,XAUUSD.DWX,XTIUSD.DWX`

## Next action

- Continue serialized unresolved-symbol loop for the remaining six symbols, with reconcile guard.
