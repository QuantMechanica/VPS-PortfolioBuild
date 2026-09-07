# QM5_12943 Q02 infrastructure recovery — strict CPU stop

Recorded: 2026-09-07T16:21:55Z (18:21 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `fc6c6f99b1ee8fd05aa6c613ee715a08b747c897`

## Outcome

The distinct structural FX recovery candidate
`QM5_12943_robopip-hlhb-trend-catcher-h1` remained ready for an append-only
`EURUSD.DWX` H1 Q02 retry, but the binding paced-fleet CPU gate refused the
enqueue. No successor row was created and no tester was launched.

The nominal higher-diversity market-neutral FX backlog identity `QM5_34008`
was not duplicated: it already has a separate governed compile item pending.
`QM5_12943` remained the newest collision-free structural FX Q02/Q03
infrastructure strand identified by the read-only farm scan.

## Revalidated recovery identity

- Source work item: `2b04b129-89e8-4489-8653-5dac22f8439a`
- Source state: `failed / INFRA_FAIL`, unclaimed
- Immutable reason: `worker_crashed_handling_item`
- Open QM5_12943 Q02 successors after refusal: zero
- Current and source-bound EX5 SHA-256:
  `95ba06400a66dfa39e31dd09855beb3f4c64f8ee4d2573d5f6476c63234155b2`
- Current MQ5 SHA-256:
  `6ebb42799e23755d3c31c1de56dca0c9c4023e60ccd4519cd9256f34c239161a`
- EURUSD backtest setfile SHA-256:
  `8e1604e168b117a130a92285d3892352151c85a5c49965e71a9345fadd726586`
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

The prior diagnosis remains controlling: the tester never launched because
the worker crashed while persisting an SH3 spawn-refusal taxonomy. Commit
`c1fe07e30f` repaired that writer and `b63bf8b6e8` added the authenticated
same-binary recovery path. No EA strategy or binary change is justified.

## Binding capacity refusal

The five one-second whole-host CPU samples immediately before the guarded
enqueue branch were:

`80.0%`, `80.0%`, `97.0%`, `92.0%`, `97.0%`.

Average CPU was `89.2%` and maximum CPU was `97.0%`. Admission requires both
values to be strictly below `97%`; equality fails the rule. The command branch
therefore exited before invoking `farmctl enqueue-backtest`.

The post-refusal fleet snapshot showed five governed terminals running (`T4`,
`T6`, `T7`, `T8`, and `T9`), no duplicate terminal workers, and no orphaned
terminal processes. This does not override the independent CPU failure.

## PACER guard and safety

No generated `.mq5` was written or edited, and no enqueue-compile boundary was
entered. The post-write framework-input pin audit was therefore not required
on this wake. No compile command, queue mutation, Strategy Card, EA, setfile,
registry, resolver, portfolio gate, `T_Live` manifest, live terminal, or
AutoTrading state was changed.

Machine-readable receipt:
`artifacts/qm5_12943_q02_infra_recovery_cpu_stop_20260907T162155Z.json`.

## Resume contract

Take a fresh five-sample CPU window. Only when both its average and maximum are
strictly below `97%`, rerun the already authenticated append-only command from
`docs/research/QM5_12943_Q02_INFRA_RECOVERY_CPU_STOP_2026-09-07.md`. The farm
controller must remain the atomic duplicate guard.
