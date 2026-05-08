# QUA-662 isolated retry findings (2026-05-01T10:45Z)

## Scope

Heartbeat continuation on zero-trades recovery lane for `QM5_1003` (`ea_id=1003`) after mixed `EA_MAGIC_NOT_REGISTERED` / trade-flow state.

## Concrete execution

- Enforced T1 isolation by stopping only T1-scoped processes:
  - `terminal64.exe` (portable T1 path)
  - `metatester64.exe` (T1 local agent)
- Ran fresh isolated smoke:
  - command: `framework/scripts/run_smoke.ps1`
  - run tag: `20260501_103949`
  - report root: `D:\QM\reports\pipeline\QM5_1003\P2_isolated_retry`

## Results

- `run_smoke.result=FAIL`
- `reason_classes=NO_REAL_TICKS_MARKER;MODEL4_MARKER_REQUIRED`
- summary:
  - `D:\QM\reports\pipeline\QM5_1003\P2_isolated_retry\QM5_1003\20260501_103949\summary.json`

Filesystem truth (this run):
- report files present: `2`
- nonzero report files: `2/2`
- byte size each: `22332`

## Critical contradiction (deterministic)

1. Tester logs show active order/deal flow (non-zero runtime behavior):
   - `D:\QM\reports\pipeline\QM5_1003\P2_isolated_retry\QM5_1003\20260501_103949\raw\run_01\20260501.log`
   - `D:\QM\reports\pipeline\QM5_1003\P2_isolated_retry\QM5_1003\20260501_103949\raw\run_02\20260501.log`

2. Exported MT5 HTML reports are structurally malformed / zeroed:
   - `Period: M0 (1970.01.01 - 1970.01.01)`
   - `Initial Deposit: 0`
   - `Leverage: 1:0`
   - `Bars: 0`, `Ticks: 0`, `Total Trades: 0`

3. Source and canonical copied reports are byte-identical (copy step is not the corruption origin):
   - source: `D:\QM\mt5\T1\QM5_1003_EURUSD_DWX_20260501_103949_run_01.htm`
   - canonical: `...\raw\run_01\report.htm`
   - same for run_02

## Classification

- Not an EA-edge weakness.
- Not a simple `NO_REPORT` (files are nonzero).
- This is a tester/report export integrity defect (runtime or launcher path) producing invalid HTML summary payload while execution logs show trading.

## Unblock owner/action

- owner: CTO + Development + Pipeline-Operator
- action:
  1. Fix MT5 report export integrity for this invocation path (valid settings header and metrics population required).
  2. Add run-level consistency guard: if trade/deal events exist in tester log but report header shows `M0/1970` or `Deposit=0`, classify as `REPORT_CORRUPT` and fail hard.
  3. Re-run P2 from clean isolated lane only after integrity fix; regenerate `report.csv` from integrity-passing runs only.

## Next action

- Hold downstream phases (`P3.5+`) as non-promotable until this integrity defect is resolved and a clean P2 rebuild is produced.
