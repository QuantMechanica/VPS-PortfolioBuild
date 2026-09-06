# QM5_41369 XTI/XNG Leader-Persistence Continuation — Build and Q02 CPU Stop

## Outcome

`QM5_41369_xtixng-cs-leadpersist-cont` is a committed, non-live V5 commodity
basket build on `agents/board-advisor`. Its reputable-source packet, durable
source approval, G0-approved Strategy Card, deterministic EA/magic allocation,
MQL5 source, basket manifest, three fixed-risk backtest presets, and reference
fixtures are committed.

The governed compile work item exists and is pending behind
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. Q02 was not enqueued: the canonical intake
requires `COMPILE_OK`, and the required fresh CPU window independently reached
the binding 97% ceiling. The mission stopped without releasing the compile
hold or launching a tester.

## Structural Edge

At the first synchronized D1 bar of a new Monday-anchored broker week, the EA
reconstructs the last three completed synchronized XTI/XNG weekly endpoints.
It requires both contracts to share a strict sign in each of the last two
weekly intervals and requires the same contract to have the larger return in
both. It buys that persistent relative winner and sells the loser as one
equal-notional, aggregate-fixed-risk package, exiting in the next broker week.

This is mechanically distinct from the one-week common-shock continuation
`QM5_41367`, the two-week leader-switch fade `QM5_41368`, the one-week fade
`QM5_41361`, opposite-sign decoupling cards `QM5_41365`/`QM5_41366`, and the
relative-return deceleration card `QM5_41362`. Canonical dedup found no exact
identity across 4,849 registry rows and 1,462 repository cards. The external
Strategy Wiki root was unavailable and remains the documented coverage limit.

## Build Evidence

- Source approval commit: `fb3c81968563b71c90c3c600b1ef114dc8b8dcc5`.
- Approved card/identity commits: `f944d136a323982ae9602e5ff5b5639c9a4939cb`
  and `ca41afb6663e9d5851e06d4c85af40af8bc1fee8`.
- Deterministic magic allocation commit:
  `8e3c299787b8faa988596c26141673767e58ded3`.
- Build commit: `a61043136aec6f84e3438675539fafacd03d19c2`.
- Reference hardening commit:
  `e37769928ad1df7f924ea427a703404d9a7c577e`.
- MQ5 SHA-256:
  `732702883032eca55718f1046cd2a8428a570b2c93264001a0ecc00c5378a94c`.
- Mandatory framework-input pin audit: `ok=true`, `hit_count=0`, no
  `EA_FRAMEWORK_INPUT_PINNED` finding.
- The guard pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and
  the fixed-risk mode (`RISK_FIXED>0`, `RISK_PERCENT==0`). It does not compare
  RNG, news, Friday-close, or portfolio-weight inputs. Stress rejection is
  checked only for finiteness and inclusive `[0,1]` range.
- Card schema lint: PASS with no missing section and no ML hit.
- Deterministic reference model: 7/7 tests PASS.
- All three backtest presets declare `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Compile item: `c283f5a0-9b7d-4c51-bb9d-9f4bd93dd4d7`, created
  `2026-09-06T14:24:33Z`, status `pending`, activation-held.
- No `.ex5` exists yet; no compile-success claim is made.

## Q02 Admission Stop

The canonical read-only first-Q02 intake returned
`compile_work_item_not_done_compile_ok`. At
`2026-09-06T14:26:33.7632720Z`, five one-second whole-host CPU samples were
`95.022579`, `91.156445`, `89.762659`, `94.104625`, and `99.419365` percent.
Average utilization was `93.893135%`; maximum utilization was `99.419365%`.
Admission requires both average and maximum to be strictly below 97%, so the
maximum binds. No Q02 row was created.

Resume only after the governed compile becomes `COMPILE_OK` and a new
five-sample CPU window clears the ceiling. Then apply the canonical first-Q02
intake bound to compile item `c283f5a0-9b7d-4c51-bb9d-9f4bd93dd4d7`.

## Safety Boundary

No portfolio gate, `T_Live`, deploy/live manifest, AutoTrading, manual
backtest, optimization, terminal restart, compile-hold bypass, priority boost,
or live surface was touched.
