# QM5_11096 FX Q02 stale-resolver repair

Date: 2026-08-11

Branch: `agents/board-advisor`

Disposition: `REPAIRED_Q02_REENQUEUE_DEFERRED_CPU_CEILING`

## Scope and farm claim

- Farm claim: `7f7824ab-5ad3-45f0-a55f-48257ef0ae79`
- Claim key: `manual:codex:agents/board-advisor:QM5_11096:q02-stale-resolver-recovery:2026-08-11T06:10:56.682276+00:00`
- Pre-claim DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11096_q02_magic_repair_20260811T061056Z.sqlite`
- EA: `QM5_11096_tdi-mbl-cross`
- Q02 symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX`
- Exact diagnostic source row: `19692f23-7fa5-46ff-b5cd-152d7b5055b3` (`EURUSD.DWX`)

The claim transaction rechecked that no pending or active Q02/Q03 row and no
open agent claim existed for this EA. The approved card cites the public
EarnForex TDI GitHub implementation, is R1-R4 PASS, uses deterministic fixed
rules with no ML/grid/martingale, runs on H1, and expects 45 trades per year per
symbol. The EA has no economic Q02 verdict and no Q04-or-later row.

The registry-ready never-pipelined build backlog contained only four M5/M15
cards expecting 90-120 trades per year, so none met this mission's
low-frequency/diversity constraint. QM5_11096 was the highest-value unclaimed
priority-2 repair because it can expose three FX instruments to the funnel from
one unchanged binary.

## Diagnosis

The authenticated EURUSD evidence is:

`D:\QM\reports\work_items\19692f23-7fa5-46ff-b5cd-152d7b5055b3\QM5_11096\20260728_173437\summary.json`

It records `ONINIT_FAILED;INCOMPLETE_RUNS` and proves that the canonical and
deployed EX5 were stable and identical during the run:

- EX5 SHA-256: `382cb168d63f75dc89d095e564ede3870f1e82e6fe804cde5eaa75a295e1b09d`
- MQ5 SHA-256: `08f6463ac2ff8bfc6b76d52a710e93f7645b98e9927ffb73fbec7fb07610433e`
- Setfile SHA-256: `4e22c698a835517b287f12d42753eff82c7efa019a7af6d1b16d381cb2a8ca5b`
- News bundle: `OK`
- Model: `4`

The governed registry contains four active rows for EA 11096:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | EURUSD.DWX | 110960000 |
| 1 | GBPUSD.DWX | 110960001 |
| 2 | USDJPY.DWX | 110960002 |
| 3 | XAUUSD.DWX | 110960003 |

The committed generated resolver also contains those rows. With an unchanged
EA source, a stable pre-fix EX5 failing during framework initialization, and
valid current governance rows, the actionable defect class is the stale
resolver include embedded in the old binary. This is the same compile-profile
skew class addressed by the current `compile_one.ps1` include synchronization;
it is not an economic strategy verdict.

## Repair and verification

The unchanged MQ5 was compiled from a clean detached worktree at
`7df1997408656c738702723a056842f704608d5c`, so unrelated working-tree changes
to the magic registry/resolver were not incorporated.

- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:\QM\reports\compile\qm5_11096_repair_20260811\20260811_061554\QM5_11096_tdi-mbl-cross.compile.log`
- Build check (`-SkipCompile`, after the strict compile): PASS, 0 failures,
  0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260811_061641.json`
- Previous EX5 SHA-256:
  `382cb168d63f75dc89d095e564ede3870f1e82e6fe804cde5eaa75a295e1b09d`
- Repaired EX5 SHA-256:
  `0d8aba4ccb525674088741e14499a1f76b2210a031795c695c1b5cd4aaabd51f`
- Strategy MQ5 was unchanged.
- All four backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`;
  their generated build hashes were refreshed.

A preliminary DEV1 MetaEditor invocation was rejected because the
Administrator-side DEV1 data profile lacked the standard `Trade/Trade.mqh`
library. It produced no accepted artifact. The standard T1 MetaEditor path then
completed the strict compile above; no tester was launched by either action.

## CPU ceiling and deterministic continuation

At the post-build capacity check, host CPU load was 100% and the farm had ten
active work items across T1-T10. This exceeds the paced-fleet backtest ceiling.
Per mission instruction, no smoke, manual MT5 dispatch, or Q02 enqueue was
performed.

Once capacity is below the ceiling, first verify that no pending/active
QM5_11096 Q02 row exists and that the current EX5 still has SHA-256
`0d8aba4ccb525674088741e14499a1f76b2210a031795c695c1b5cd4aaabd51f`.
Then enqueue exactly one append-only EURUSD canary:

```powershell
python C:\QM\repo\tools\strategy_farm\farmctl.py enqueue-backtest `
  --ea QM5_11096 `
  --phase Q02 `
  --append-only-rerun-of 19692f23-7fa5-46ff-b5cd-152d7b5055b3 `
  --rerun-reason "stale resolver EX5 repaired; retry EURUSD Q02 after CPU ceiling clears" `
  --expected-current-ex5-sha256 0d8aba4ccb525674088741e14499a1f76b2210a031795c695c1b5cd4aaabd51f
```

The remaining three symbols should be re-enqueued only after the canary proves
framework initialization. No portfolio-gate, deploy-manifest, T_Live, or
AutoTrading state was read-write touched.
