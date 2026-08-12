# QM5_11481 forex Q02 infrastructure diagnosis

- Mission lane: priority 2, diverse-instrument Q02/Q03 infrastructure recovery
- Farm claim: `e480aa6d-be9e-47de-8de6-dd1243aa65e8`
- EA: `QM5_11481_carter-t-ny-open-box-m5`
- Instruments diagnosed: `GBPJPY.DWX`, `USDJPY.DWX`
- Result: `DEFERRED_CPU_CEILING`

## Diagnosis

The latest completed Q02 reports are infrastructure failures, not strategy
verdicts. All three attempts for each symbol produced a non-empty tester report
with the Model-4 marker but zero bars and the invalid-report tuple
`EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`, `BARS_ZERO`.

Evidence:

- `D:\QM\reports\work_items\afb12fd5-d0d0-42fa-80ad-212b3a89e4d2\QM5_11481\20260710_111111\summary.json`
- `D:\QM\reports\work_items\2323173d-0a6f-4e39-a294-651a808f5041\QM5_11481\20260710_112403\summary.json`

Preflight also confirmed that the EA identity is `qm_ea_id=11481`, all five
registered forex symbols have canonical backtest setfiles, and every setfile
uses `RISK_FIXED=1000` with `RISK_PERCENT=0`. The observed failure therefore
belongs to terminal custom-symbol history availability/synchronization; it is
not an `OnInit` identity failure and provides no evidence for changing strategy
logic.

## Farm coordination and stop condition

The claim was acquired atomically only after confirming that QM5_11481 had no
pending or active work item and no competing infrastructure-recovery claim.
Immediately after claiming, the farm reported 8 active Q02-Q08 backtests. The
paced ceiling is 7, so no new work item was inserted, reopened, dispatched, or
run. Re-enqueue is intentionally deferred until the active count is below the
ceiling and a terminal with synchronized `GBPJPY.DWX`/`USDJPY.DWX` M5 history
is available.

No T_Live, AutoTrading, portfolio gate, deploy manifest, EA source, binary,
registry, or setfile was changed.
