# QUA-947 Recovery Summary — QM5_1004 P2 timeout/hang + FAIL/INVALID aggregation

- Generated at (UTC): 2026-05-08T19:14:00Z
- Source report: `D:\QM\reports\pipeline\QM5_1004\P2\report.csv`
- Report last write (UTC): 2026-05-08T16:59:45Z
- Report size: 26735 bytes
- `.htm` files under P2 tree: 283

## Verdict aggregation (report.csv)
- FAIL: 172
- INVALID: 35
- PASS: 0

## Top invalidation reasons
- 138: `run_smoke_fail:MIN_TRADES_NOT_MET`
- 30: `no_summary_json:rc=1`
- 27: `run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS`
- 6: `run_smoke_fail:REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`
- 2: `run_smoke_timeout`
- 3 total setfile-missing rows (`US500.DWX` H1/H4/D1)

## Timeout/Hang indicators
- Latest runner log `run_stdout_20260508T085216Z.log` contains repeated exception:
  - `run_smoke.ps1:147 throw "Terminal resolution returned no terminal..."`
- `no_summary_json:rc=1` symbols (24 unique):
  - AUDCAD.DWX, AUDCHF.DWX, AUDJPY.DWX, AUDNZD.DWX, AUDUSD.DWX, CADCHF.DWX, CADJPY.DWX, CHFJPY.DWX, EURAUD.DWX, EURCAD.DWX, EURCHF.DWX, EURGBP.DWX, EURJPY.DWX, EURNZD.DWX, EURUSD.DWX, GBPAUD.DWX, GBPCAD.DWX, GBPCHF.DWX, GBPJPY.DWX, GBPNZD.DWX, GBPUSD.DWX, GDAXI.DWX, NDX.DWX, NZDCAD.DWX
- `run_smoke_timeout` observed on AUDCAD.DWX (2 rows)
- `METATESTER_HUNG` appears in 6 rows (AUDCHF.DWX, AUDJPY.DWX, NZDCHF.DWX, EURAUD.DWX, US500.DWX)

## Additional observations
- `p2_QM5_1004_result.json` currently reflects a DRY snapshot (`DRY=37`, FAIL/INVALID/PASS=0), which does not match accumulated `report.csv` history.
- Operationally, use `report.csv` as primary aggregation for this issue.

## Unblock owner/action
- Owner: CTO / pipeline-runner maintainer
- Action:
  1. Fix terminal selection/availability path in `framework/scripts/run_smoke.ps1` around line 147 ("no terminal" exception).
  2. Re-run `p2_baseline.py --ea QM5_1004 --resume` after fix.
  3. Keep US500 setfile remediation tracked separately (H1/H4/D1 setfile rows already captured).

## Addendum (superseding stale snapshot)
- Update source: QUA-947 comment `287b9df3-e972-496b-b32d-c3c1c20ab384` at 2026-05-08T17:14:58Z.
- Filesystem truth (later check) for `D:/QM/reports/pipeline/QM5_1004/P2`:
  - `report.csv` exists, 26,735 bytes, last write 2026-05-08 18:59:45 local.
  - `.htm` files present: 283.
  - zero-size `.htm` files: 0.
- Correction: earlier statement "No `.htm` files present" is stale/incorrect for the later snapshot.
- Later recovery pass classified the active `p2_baseline.py --ea QM5_1004` process tail as stalled/hung and terminated PID `16132`.
- Later recovery snapshot reported:
  - `rows=144`, `unique_symbols=36`
  - verdicts `FAIL=137`, `INVALID=7`, `PASS=0`
  - modal reason `run_smoke_fail:MIN_TRADES_NOT_MET` (111 rows)
