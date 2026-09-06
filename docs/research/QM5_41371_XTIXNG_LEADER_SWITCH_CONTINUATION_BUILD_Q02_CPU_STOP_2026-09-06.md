# QM5_41371 XTI/XNG Leader-Switch Continuation — Build and Q02 CPU Stop

## Outcome

`QM5_41371_xtixng-cs-leadswitch-cont` is a committed, non-live V5 commodity
basket source build on `agents/board-advisor`. Its reputable-source packet,
durable source approval, G0-approved Strategy Card, deterministic EA/magic
allocation, MQL5 source, basket manifest, three fixed-risk backtest presets,
and deterministic reference fixtures are committed.

The governed Q01 compile item exists but is pending behind
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. Q02 was not enqueued: the canonical intake
requires `COMPILE_OK`, and the fresh CPU window independently hit the binding
97% maximum ceiling. No compile hold was released and no tester was launched.

## Structural Edge

At the first synchronized D1 bar of a new Monday-anchored broker week, the EA
reconstructs the last three completed synchronized XTI/XNG weekly endpoints.
It requires both contracts to share a strict sign in each of the last two
weekly intervals and requires the relative leader to switch. It buys the new
relative winner and sells the loser as one equal-notional,
aggregate-fixed-risk package, exiting in the next broker week.

This is mechanically distinct from `QM5_41368`, which fades the same strict
leader-switch state; `QM5_41369`, which follows only when leadership persists;
`QM5_41367`, which uses one common-sign week; and the opposite-sign decoupling
EA `QM5_41366`. Canonical dedup found no exact identity across 4,851 registry
rows and 1,464 repository cards. The external Strategy Wiki root was
unavailable and remains the documented coverage limit.

## Build Evidence

- Source approval commit: `52c5c4c9a1`.
- Approved card and EA identity commit: `fd446e1ef8`.
- Deterministic magic allocation commit: `f63ba81507`.
- EA source/build-artifact commit: `b7ebbf24ee`.
- MQ5 SHA-256:
  `4017050adb5aee7028eb69c84d6d01cb880f6cbcba81fe4af19ec4e53c4ffe5a`.
- Mandatory framework-input pin audit: `ok=true`, `hit_count=0`, no
  `EA_FRAMEWORK_INPUT_PINNED` finding. It was rerun immediately before compile
  enqueue.
- The guard pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and
  fixed-risk mode (`RISK_FIXED>0`, `RISK_PERCENT==0`). It does not compare RNG,
  news, Friday-close, or portfolio-weight inputs. Stress rejection receives
  only finiteness and inclusive `[0,1]` range checks.
- Card schema/ML lint: PASS with no missing section and no ML hit.
- Deterministic reference model: 7/7 tests plus 4 subtests PASS.
- All three presets declare `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Compile item: `b1ae3e09-0ccc-4356-b6b6-6d79a183c358`, status `pending`,
  activation-held. No `.ex5`, strict build-check receipt, or compile-success
  claim exists.

## Q02 Admission Result

The canonical read-only first-Q02 intake returned
`compile_work_item_not_done_compile_ok`. At
`2026-09-06T16:26:17.4210126Z`, five one-second whole-host CPU samples were
`99.122159%`, `99.708244%`, `100.000000%`, `92.194491%`, and `90.136738%`.
Average utilization was `96.232326%`; maximum utilization was `100.000000%`.
The maximum was not strictly below the 97% hard ceiling, so the explicit CPU
stop applies independently of the missing `COMPILE_OK` precondition. No Q02
row was created.

Resume only after the governed compile becomes `COMPILE_OK`, then take a new
five-sample CPU window. Apply the following only if both its average and
maximum are strictly below 97%:

```powershell
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id b1ae3e09-0ccc-4356-b6b6-6d79a183c358 --apply
```

## Safety Boundary

No portfolio gate, `T_Live`, deploy/live manifest, AutoTrading, manual
backtest, optimization, terminal restart, compile-hold bypass, priority boost,
or live surface was touched.
