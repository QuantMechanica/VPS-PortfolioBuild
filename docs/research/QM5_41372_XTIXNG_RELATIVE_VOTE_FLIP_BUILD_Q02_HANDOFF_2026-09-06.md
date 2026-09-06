# QM5_41372 XTI/XNG relative-vote flip build and Q02 handoff

Date: 2026-09-06  
Scope: branch-only commodity/energy card, build, governed compile, and paced Q02 admission

## Outcome

`QM5_41372_xtixng-wrelvote-flip-cont` was approved, allocated, and built as a
low-frequency XTI/XNG structural basket. The MQL5 source and three fixed-risk
backtest presets are committed. The generated source passed the binding PACER
input-pin audit with zero findings immediately before the governed compile was
enqueued.

The compile row was released through the exact one-item rollout path and
returned `COMPILE_OK` with zero compiler errors or warnings and a passing build
check. Q02 was not enqueued: governed workers observed CPU loads above the 97%
backtest ceiling, which activates the OWNER instruction to stop and summarize.

## Strategy contract

- Carrier: equal-notional `XTIUSD.DWX` / `XNGUSD.DWX` basket.
- Frequency: one persistent entry attempt per broker week.
- Signal: compare the sign-majority vote of three older weekly relative returns
  with the overlapping three-week vote advanced by one week. Enter only on a
  strict vote reversal and continue in the newest majority direction.
- Exit: close in the next broker week, with ten-day stale-package repair.
- Risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, opposed legs, and
  broker-side `3.5 * ATR(20)` hard stops.
- Boundaries: no ML or banned indicator, no Friday-close override, no live or
  portfolio authority.

## Build and guard evidence

- Source approval commit: `c2b9a683f1`.
- G0/card commit: `954ff15462`.
- EA/magic allocation commit: `85cb06c160`.
- Source/build commit: `7677eb056c`.
- Source SHA-256:
  `17389f139e130d985a7a44459effc528f89fbd1e224e5301b99c8f14f452f637`.
- Reference tests: six passed.
- Card schema lint: passed.
- PACER audit: exit 0, `ok=true`, `hit_count=0`, empty findings.
- PACER command, run immediately before enqueue:
  `python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_41372_xtixng-wrelvote-flip-cont/QM5_41372_xtixng-wrelvote-flip-cont.mq5`.

The locked-configuration guard checks only the strategy contract, EA identity,
magic offset, fixed-risk mode, and stress-input finiteness/range. It does not
compare RNG seed, news inputs, Friday-close inputs, or stress probability to a
default value.

## Governed compile state

- Work item: `e0781e04-0d31-48de-a5ba-227e47965c2d`.
- Exact rollout release: one row, at `2026-09-06T19:17:58Z`.
- State at handoff: `done/COMPILE_OK`; compiler PASS with zero errors and zero
  warnings; build check PASS; three fixed-risk setfiles generated.
- Compiled artifact SHA-256:
  `d6bed0ca4bb1a646cfb713110b32a53bd632ef88bfae727cc63713a15a5821ec`.
- Compile evidence:
  `D:/QM/reports/work_items/e0781e04-0d31-48de-a5ba-227e47965c2d/QM5_41372/COMPILE_EA/compile_evidence.json`.
- Release evidence:
  `artifacts/qm5_41372_compile_release_dry_run_20260906.json` and
  `artifacts/qm5_41372_compile_release_apply_20260906.json`.

No ad-hoc compiler or manual tester was launched. The compile was claimed and
completed by the normal terminal-worker lane on `T6`.

## CPU ceiling and Q02 decision

Before the ceiling event, two five-sample checks cleared the threshold (maximums
96.78% and 92.78%). During the subsequent queue wait, the governed worker logs
recorded 98.2%, 98.7%, 98.5%, and 97.9% against the 97% threshold between
`19:25:07Z` and `19:26:24Z`. That is the binding stop condition.

Therefore:

- Q02 work items appended: **zero**.
- Backtest capacity added: **zero**.
- Required resume condition: a fresh CPU admission sample clears the configured
  ceiling before invoking the canonical `intake-first-q02` path exactly once.

Machine-readable handoff: `artifacts/qm5_41372_q02_admission_20260906.json`.

No `T_Live`, AutoTrading, portfolio-gate, live-manifest, deployment, or live-use
state was touched.
