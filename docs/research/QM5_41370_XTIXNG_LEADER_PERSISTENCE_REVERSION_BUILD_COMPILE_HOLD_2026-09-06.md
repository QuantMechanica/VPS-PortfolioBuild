# QM5_41370 XTI/XNG Leader-Persistence Reversion — Build and Compile Hold

## Outcome

`QM5_41370_xtixng-cs-leadpersist-rv` is a committed, non-live V5 commodity
basket source build on `agents/board-advisor`. Its reputable-source packet,
durable source approval, G0-approved Strategy Card, deterministic EA/magic
allocation, MQL5 source, basket manifest, three fixed-risk backtest presets,
and reference fixtures are committed.

The governed Q01 compile item exists but is pending behind
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. Q02 was not enqueued because the canonical
intake requires `COMPILE_OK`. The fresh CPU window passed independently. No
compile hold was released and no tester was launched.

## Structural Edge

At the first synchronized D1 bar of a new Monday-anchored broker week, the EA
reconstructs the last three completed synchronized XTI/XNG weekly endpoints.
It requires both contracts to share a strict sign in each of the last two
weekly intervals and the same contract to be the relative leader in both. It
sells that persistent relative winner and buys the loser as one equal-notional,
aggregate-fixed-risk package, exiting in the next broker week.

This is mechanically distinct from `QM5_41369`, which follows the same
formation; `QM5_41368`, which fades only after leadership switches;
`QM5_41361`, which is a one-week fade; and the opposite-sign decoupling EAs
`QM5_41365`/`QM5_41366`. Canonical dedup found no exact identity across 4,850
registry rows and 1,463 repository cards. The external Strategy Wiki root was
unavailable and remains the documented coverage limit.

## Build Evidence

- Source approval commit: `8f4466ecc8`.
- Approved card and EA identity commit: `bf1acb244f`.
- Deterministic magic allocation commit: `fa09efec6e`.
- EA source/build-artifact commit: `ace0806252`.
- MQ5 SHA-256:
  `78fd2cfdc16e012e9102392773194427c6d358614b115707877b30343cb1eb94`.
- Mandatory framework-input pin audit: `ok=true`, `hit_count=0`, no
  `EA_FRAMEWORK_INPUT_PINNED` finding. It was rerun immediately before compile
  enqueue.
- The guard pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and
  fixed-risk mode (`RISK_FIXED>0`, `RISK_PERCENT==0`). It does not compare RNG,
  news, Friday-close, or portfolio-weight inputs. Stress rejection receives
  only finiteness and inclusive `[0,1]` range checks.
- Card schema/ML lint: PASS with no missing section and no ML hit.
- Deterministic reference model: 7/7 tests PASS.
- All three presets declare `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Compile item: `0ad1ce90-012b-4595-90e8-838897197e89`, status `pending`,
  activation-held. No `.ex5`, strict build-check receipt, or compile-success
  claim exists.

## Q02 Admission Result

The canonical read-only first-Q02 intake returned
`compile_work_item_not_done_compile_ok`. At
`2026-09-06T15:24:22.5832251Z`, five one-second whole-host CPU samples were
`84.382901`, `88.597041`, `92.582773`, `92.191396`, and `92.971569` percent.
Average utilization was `90.145136%`; maximum utilization was `92.971569%`.
Both were strictly below the 97% ceiling, but CPU capacity cannot waive the
missing `COMPILE_OK` precondition. No Q02 row was created.

Resume only after the governed compile becomes `COMPILE_OK`, then take a new
five-sample CPU window. If it still clears the ceiling, apply:

```powershell
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 0ad1ce90-012b-4595-90e8-838897197e89 --apply
```

## Safety Boundary

No portfolio gate, `T_Live`, deploy/live manifest, AutoTrading, manual
backtest, optimization, terminal restart, compile-hold bypass, priority boost,
or live surface was touched.
