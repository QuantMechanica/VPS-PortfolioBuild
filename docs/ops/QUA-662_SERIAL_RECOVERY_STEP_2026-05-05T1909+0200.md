# QUA-662 serialized recovery step — 2026-05-05T19:09+02:00

## Action taken

- Executed one-off symbol recovery for:
  - `AUDUSD.DWX` on `T2`

Command:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols AUDUSD.DWX --terminal T2 --year 2024 --runs 2 --out-prefix D:\QM\reports\pipeline --timeout 1800`

## Direct outcome (requested symbol)

- Failure class:
  - `run_smoke_fail:REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`
- Evidence:
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_170718\summary.json`

## Observed side-effect / global progress

- During/after this run, additional rows were appended from concurrent/background runner activity.
- `report.csv` line count jumped:
  - before: `14`
  - after: `19`
- Canonical coverage snapshot now:
  - `12 / 36` symbols covered
  - `24` symbols remaining

Remaining canonical symbols:
- `CADCHF.DWX,CADJPY.DWX,CHFJPY.DWX,EURCAD.DWX,EURCHF.DWX,EURGBP.DWX,EURJPY.DWX,EURNZD.DWX,EURUSD.DWX,GBPCAD.DWX,GBPCHF.DWX,GBPJPY.DWX,GBPNZD.DWX,GBPUSD.DWX,GDAXIm.DWX,NZDCHF.DWX,NZDJPY.DWX,NZDUSD.DWX,USDCAD.DWX,USDJPY.DWX,WS30.DWX,XAUUSD.DWX,XNGUSD.DWX,XTIUSD.DWX`

## Next action

- Continue serialized one-symbol recovery, but re-snapshot coverage before each step because background rows are now landing asynchronously.
