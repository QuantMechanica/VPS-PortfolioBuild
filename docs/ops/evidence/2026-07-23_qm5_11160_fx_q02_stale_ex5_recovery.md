# QM5_11160 diverse-FX Q02 stale-EX5 recovery

Date: 2026-07-23  
Task: `2ce555a1-f57a-4949-8d33-2f36dfb7ea29`  
EA: `QM5_11160_dwx-brk-risk`

## Selection and claim

- No unbuilt diverse card was available in the approved build backlog.
- The selected card is OWNER-approved (`g0_status: APPROVED`) and cites the official
  Darwinex article "The Journey of an Automated Trading Expert".
- The strategy is a structural H1 price-channel breakout with ATR stop, fixed target,
  time stop, one position per symbol, and no ML/grid/martingale logic.
- The prior recovery was explicitly recycled because `compile_one.ps1` had left the
  repository EX5 byte-identical to the stale binary and no Q02 row was enqueued.
- The farm task was atomically reclaimed from `RECYCLE` to `IN_PROGRESS`.
- Claim backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11160_reclaim_20260723T074630Z.sqlite`

## Build evidence

- Command:
  `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_11160_dwx-brk-risk/QM5_11160_dwx-brk-risk.mq5 -Strict`
- Compile result: PASS, 0 errors, 0 warnings.
- Compile summary:
  `D:\QM\reports\compile\20260723_074648\summary.csv`
- Compile log:
  `C:\QM\repo\framework\build\compile\20260723_074648\QM5_11160_dwx-brk-risk.compile.log`
- Standalone build gate:
  `framework/scripts/build_check.ps1 -EALabel QM5_11160_dwx-brk-risk -RepoRoot C:\QM\repo -SkipCompile`
- Build gate result: PASS, 0 failures, 0 warnings.
- Build-gate report:
  `D:\QM\reports\framework\21\build_check_20260723_074726.json`
- MQ5 SHA-256:
  `30df156cfaa65030c3daea2f76b3d7bb71fb76db7fc493629288aebd62f423ea`
- Fresh EX5 SHA-256:
  `43fce17fb18fe2e09b3a1767b54ed3d244be074a02164fcd45e11862c082e774`
- Freshness proof: repository EX5 changed from 243,564 bytes (2026-07-12) to
  345,768 bytes (2026-07-23). Its Git blob differs from the stale
  `208a2e3447aa2880cd7447aaae4ecb0ae32425c8` binary recorded by the recycled
  attempt.

## Q02 queue handoff

The runtime DB was backed up to
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11160_q02_requeue_20260723T074800Z.sqlite`.
No open QM5_11160 Q02/Q03 row existed. Three existing Q02 `INFRA_FAIL` rows were
reopened in place, with fresh MQ5/EX5/setfile evidence hashes:

| Symbol | Work item |
|---|---|
| EURUSD.DWX | `e4901522-6949-4f4a-8e24-8fe151224d8b` |
| GBPUSD.DWX | `43c2e13b-7db7-41dc-a995-6fd7e007d50a` |
| USDJPY.DWX | `2e43c17a-a192-43a6-b413-a3f7a00b503d` |

All three rows were reset to `pending`, with `attempt_count=0`, no claimant, no
verdict, `effective_min_trades=25`, and the diversity-frontier priority flag. No
duplicate work item was created.

## CPU ceiling and safety

`farmctl.py mt5-slots` showed active pipeline tests on T1, T2, T3, T4, T6, T7,
T9, and T10. No manual smoke/backtest was launched. This unit did not access or
change T_Live, AutoTrading, the portfolio gate, any deploy manifest, or any live
setfile.
