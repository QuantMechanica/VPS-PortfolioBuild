# QM5_10518 FX Q02 infrastructure recovery

Date: 2026-07-23  
EA: `QM5_10518_mql5-sarima`  
Instrument: `EURUSD.DWX`  
Farm repair task: `c847ae5e-f303-4c96-af8d-281e9a9ff5fe`
Deferred enqueue claim: `976751af-bb96-4249-9385-20eacf058ea3`

## Diagnosis

The latest Q02 work item `c3b0ef9c-9d5c-4db3-b785-038d0559916e` ended with
`INFRA_FAIL`, reason `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS`. Its execution
identity was internally consistent: the expected MQ5 hash was
`5e94d77d59237e87c9b97f5678fcb33cbb389ae7a4d022244013e6d6c5883a63` and the
expected EX5 hash was
`aeadd9067780fbf9b88f82b674f150c333826513a5d84127ef14597e08448cef`.
This is a terminal history-availability failure, not a strategy verdict.

Evidence: `D:\QM\reports\work_items\c3b0ef9c-9d5c-4db3-b785-038d0559916e\QM5_10518\20260723_004255\summary.json`.

## Repair verification

`framework/scripts/build_check.ps1 -EALabel QM5_10518_mql5-sarima` refreshed the
EX5 from the repository source and passed cleanly:

- `compile_one.result=PASS`
- `compile_one.errors=0`
- `compile_one.warnings=0`
- `build_check.result=PASS`
- report: `D:\QM\reports\framework\21\build_check_20260723_013140.json`

No strategy source or setfile was changed.

## Dispatch disposition

The farm had 9 active work items at the repair checkpoint. Per the paced-fleet
CPU ceiling rule, no smoke/backtest was launched and no additional Q02 item was
enqueued. The refreshed binary is committed and the repair is explicitly
deferred for a later capacity-aware Q02 enqueue.

No T_Live files, AutoTrading state, portfolio gate, or T_Live manifest were
touched.

## Capacity-aware Q02 handoff

At 2026-07-23T21:31:51Z the paced fleet had five active pipeline terminals,
below the earlier nine-job ceiling checkpoint. The existing Q02 row was
requeued in place rather than duplicated:

- work item: `c3b0ef9c-9d5c-4db3-b785-038d0559916e`
- status: `pending`
- expected MQ5 SHA-256:
  `5e94d77d59237e87c9b97f5678fcb33cbb389ae7a4d022244013e6d6c5883a63`
- refreshed EX5 SHA-256:
  `ab059052ae9a00e86122adb93fd36d0f174f84b7b8b893a528a571a1f8376502`
- refreshed RISK_FIXED setfile SHA-256:
  `7b318107e1d2845e3cc250f0ae8acfdb39d6f424dc8d36d36e7b9695e43b387e`

The failed run was on T6 and its evidence was a terminal-local
`NO_HISTORY`/zero-bars report, so the pending payload excludes T6 while
retaining `EURUSD.DWX`, H1, Model 4, `RISK_FIXED=1000`, and evidence identity
binding. No backtest was launched manually.
