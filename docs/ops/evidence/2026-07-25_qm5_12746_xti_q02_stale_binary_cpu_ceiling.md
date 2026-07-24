# QM5_12746 XTI Q02 stale-binary rebuild

Date: 2026-07-25

Branch: `agents/board-advisor`

EA: `QM5_12746_eia-wti-drive-pb`

Farm claim: `723c8196-c25b-4f71-8dd1-c00ab344c06c`

## Selection

No unclaimed, buildable higher-diversity card was available. The rates and
lumber candidates require instruments absent from the Darwinex symbol matrix
and do not have complete deterministic registry allocation; other actionable
build work was already claimed. `QM5_12746` was therefore selected under the
diverse-instrument Q02 infrastructure-recovery priority.

This is an approved, non-duplicate `XTIUSD.DWX` D1 sleeve with:

- official U.S. Energy Information Administration structural lineage;
- deterministic driving-season, pullback, trend, ATR-stop, and time-exit
  rules;
- approximately 6-12 expected entries per year;
- no ML, adaptive PnL fitting, banned indicator, grid, martingale, or external
  runtime data; and
- a canonical backtest setfile with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The guarded farm claim found no pending/active work item, downstream verdict,
open task, agent claim, or prior equivalent repair for this EA.

## Failure and root cause

- Source Q02 work item:
  `5782d777-5a13-4408-98f9-107d300473c1`
- Verdict: `INFRA_FAIL`
- Reason classes: `ONINIT_FAILED`, `INCOMPLETE_RUNS`
- Latest terminal: `T2`
- Evidence:
  `D:\QM\reports\work_items\5782d777-5a13-4408-98f9-107d300473c1\QM5_12746\20260724_023047\summary.json`

The same initialization-only result was reproduced on T2, T3, T4, T6, T7,
T8, T9, and T10, with known XTI history coverage and no economic verdict.

The original binary was built in commit `bbcbb246b` with SHA-256
`0c4263f9233ff20622a2a95b666f95603ffdc566e56fa764783f768b10d51bf6`.
That commit added the active registry row
`12746 / slot 0 / XTIUSD.DWX / 127460000` but did not regenerate
`QM_MagicResolver.mqh`. The generated resolver first gained magic
`127460000` later, in commit `15f9fa7a9`. Because the EA initializes through
`QM_FrameworkInit`, the failed EX5 could not resolve its registered magic.
This was a stale build dependency, not strategy mechanics or missing history.

## Repair and validation

The unchanged MQ5 source was strictly recompiled against the current framework
and generated resolver. The canonical setfile build binding was refreshed by
the framework build check; no alpha, parameter, registry, or risk-setting
change was made.

- Strict compile: `PASS`, 0 errors, 0 warnings
  - log:
    `C:\QM\repo\framework\build\compile\20260724_225238\QM5_12746_eia-wti-drive-pb.compile.log`
  - summary: `D:\QM\reports\compile\20260724_225238\summary.csv`
- Framework build check: `PASS`, 0 failures, 0 warnings
  - report:
    `D:\QM\reports\framework\21\build_check_20260724_225237.json`
- Build guardrails: `PASS`, no findings across source and setfile
- SPEC validation: `PASS`, 1 of 1
- MQ5 SHA-256:
  `7c899bb34bca9aac1d332c23c6bb04b86bb1bb5e0f4aaa6b85c01dd9a3c11240`
- rebuilt EX5 SHA-256:
  `e5f844beeb76f9e952f8f2661c3543dd7de8e8d9399422c31eea171f319b4645`
- refreshed setfile SHA-256:
  `3ab5fc6cc6234f39c1186bbd516fdecbfcddad839568fc4d63118a5fbbfa2c95`

The farm database was backed up before the claim. Both the live database and
backup passed `PRAGMA quick_check`:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12746_q02_repair_20260724T225043Z.sqlite
```

## CPU-ceiling stop

At the stop decision, the farm had eight active factory jobs on T1, T2, T3,
T4, T6, T7, T8, and T9. This is above the documented seven-job backtest CPU
ceiling; `T_Live` is not part of that count.

Per the mission stop condition, the failed Q02 row was not reopened and no
replacement was inserted, enqueued, or dispatched. The rebuilt package is
ready for a future paced agent to re-enqueue once factory usage is below the
ceiling.

No manual smoke, pipeline phase, tester launch, `T_Live`, AutoTrading,
portfolio gate, deploy manifest, or live setfile was touched.
