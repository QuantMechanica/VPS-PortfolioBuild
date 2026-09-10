# QM5_10850 EURUSD H1 compile/Q02 recovery — source repaired, CPU stop

Date: 2026-09-10  
Branch: `agents/board-advisor`  
EA: `QM5_10850_tv-bbmr-long`  
Cell: `EURUSD.DWX`, `H1`  
Farm task: `c617c750-0098-4681-8434-60aff4418934`

## Outcome

The stale/missing-binary recovery source was repaired without changing the
Strategy Card mechanics. Compile and Q02 were **not enqueued** because the
fresh five-sample whole-host CPU window peaked at `98.341678%`, above the
binding `97.0%` ceiling.

No T_Live, AutoTrading, portfolio-gate, or deploy-manifest action was taken.

## Selection and claim

- The approved card is a structural H1 Bollinger mean-reversion strategy with
  fixed rules, no ML/grid/martingale, and EURUSD in its governed R3 basket.
- The current farm state had no pending/active `QM5_10850` work item, no open
  agent task, and no pending/active farm task before the claim.
- The farm claim was inserted atomically as task
  `c617c750-0098-4681-8434-60aff4418934`, scoped to EURUSD H1 only.
- Pre-claim SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10850_eurusd_recovery_claim_20260910T202452Z.sqlite`.

The target registry row is active:
`10850,tv-bbmr-long,4,EURUSD.DWX,108500004,...,active`.

## Diagnosis

The latest real EURUSD Q02 predecessor was
`133f2023-7786-40ea-ba08-83ccd02a93bd`, classified
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`. All five intended H1 cells had
only infrastructure-invalid Q02 outcomes; none had an economic Q02 or Q04
verdict.

The governed compile successor
`2c9c793a-ca44-4f20-8df9-f778d0867f1c` produced a clean MetaEditor compile
(`0` errors, `0` warnings) but correctly failed the aggregate build gate with:

- `EA_Q08_MAE_HOOK_MISSING`
- advisory `BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED`

The canonical `.ex5` was absent after that failed aggregate gate. Source
inspection confirmed both findings:

1. `OnTick()` did not call `QM_FrameworkTrackOpenPositionMae()` before its
   early-return guards.
2. `Strategy_NoTradeFilter()` rejected `ask == bid`. DWX tester quotes may
   validly model zero spread, so the predicate guaranteed zero entries there.

## Source repair

Only framework/tester compatibility changed:

- Added `QM_FrameworkTrackOpenPositionMae()` as the first action in `OnTick()`.
- Changed the invalid-quote test from `ask <= bid` to `ask < bid`, preserving
  rejection of crossed/negative quotes while allowing valid zero-spread tester
  quotes.

Signal construction, Bollinger/SMA parameters, 1.5% stop, middle-band target,
one-position rule, and fixed-risk sizing were unchanged.

Post-repair source SHA-256:
`6746cdadca2292330e6eab7b21dd052d9939de1ef9c312c4ec726434e13c4c44`.

The EURUSD H1 setfile remains fixed-risk:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `qm_magic_slot_offset=4`

Setfile SHA-256:
`5db38eefbcf38f832451941ed11a0bb800f10859bef83fee41997ad8029b3e51`.

## PACER build guard

After writing the `.mq5` and before any compile enqueue, the binding audit was
run exactly as required:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10850_tv-bbmr-long/QM5_10850_tv-bbmr-long.mq5"
```

Result:

```json
{
  "ok": true,
  "predicate": "EA_FRAMEWORK_INPUT_PINNED",
  "source_count": 1,
  "hit_count": 0,
  "hits": []
}
```

No framework input was pinned by the EA.

## Governed compile and CPU admission

An attempted strict build-check with `-SkipCompile` made no compile attempt and
was refused by the live-factory guard with the exact class
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. Its mandated pipeline hint was:

```text
python tools/strategy_farm/farmctl.py enqueue-compile <EA label>
```

Before using that governed enqueue path, five consecutive one-second
`\Processor(_Total)\% Processor Time` samples were:

```text
98.341678, 83.986064, 74.709761, 87.702872, 74.612064
average=83.870488
maximum=98.341678
ceiling=97.0
```

At the sample time, eight `terminal64` and six `metatester64` processes were
alive. Because the maximum was not strictly below 97%, the paced-fleet CPU
stop bound. No `enqueue-compile` command, Q02 enqueue, smoke run, or tester
launch followed.

## Deterministic continuation

After a fresh five-sample CPU window remains strictly below 97%:

1. Reconfirm no competing `QM5_10850` claim or open work item.
2. Re-run the PACER input-pin audit against the committed source.
3. Enqueue exactly one governed compile for `QM5_10850_tv-bbmr-long` and require
   aggregate build-check PASS plus a source-fresh canonical `.ex5`.
4. Require the regenerated EURUSD H1 setfile to remain `RISK_FIXED > 0` and
   `RISK_PERCENT == 0`.
5. Append exactly one EURUSD H1 Q02 successor; do not fan out the index/metal
   siblings from this recovery unit.

