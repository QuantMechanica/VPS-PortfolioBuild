# QM5_41368 XTI/XNG Leader-Switch Reversion — Build and Q02 CPU Stop

## Outcome

`QM5_41368_xtixng-cs-leadswitch-rv` is a committed, non-live V5 basket build.
Its reputable-source packet, source approval, G0-approved Strategy Card,
deterministic EA/magic allocation, MQL5 source, basket manifest, three
aggregate-fixed-risk presets, and reference tests are committed on
`agents/board-advisor`.

The current-source governed compile request is queued but remains behind the
deliberate `COMPILE_EA_WORKER_ROLLOUT_PENDING` activation hold. Q02 was not
enqueued: its compile prerequisite is not yet `COMPILE_OK`, and the required
fresh CPU admission window independently reached the binding 97% ceiling.

## Structural Edge

At the first D1 bar of a new Monday-anchored broker week, reconstruct the last
three synchronized completed XTI/XNG weekly endpoints. Require both legs to
have the same strict sign in each of the last two weekly intervals and require
the relative winner to switch between those intervals. Fade the newest winner
and buy the newest loser as one equal-notional, aggregate-fixed-risk package,
then exit in the next broker week. The signal uses only completed native D1
prices and deterministic arithmetic; it has no external feed, learned output,
or banned indicator.

This two-week leader-switch state is mechanically distinct from the existing
one-week same-sign reversion (`QM5_41361`), one-week same-sign continuation
(`QM5_41367`), and opposite-sign decoupling carriers (`QM5_41365` and
`QM5_41366`). Canonical dedup found no exact match across 4,848 registry rows
and 1,461 cards; the expected carrier-family fuzzy matches were manually
resolved before allocation.

## Build Evidence

- G0 Strategy Card: `QM5_41368`, approved 2026-09-06.
- Current MQ5 SHA-256:
  `b11bdc719cead280afd8b7d70ec931f4764bb7b345545a29e3694acd4c292f8f`.
- Current governed compile work item:
  `8b988156-b64e-4b12-aa5c-d5dc2a7d7438`, pending and activation-held.
- Its stale pre-policy predecessor
  `f5b3ca81-59cc-4b06-ae1a-963971f59933` is append-only superseded by the
  current-source row under the canonical rollout reconciliation authority.
- The source repair only removed validation comparisons that pinned
  framework-owned seed/news/Friday-close inputs. Identity, strategy, fixed
  risk, portfolio weight, and finite stress-range checks remain locked.
- Reference model: 7/7 tests pass.
- Framework-input predicate regression suite: 9/9 tests pass.
- All backtest presets declare `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The activation hold was not released. At the last process census, T9's worker
predated the framework-input policy commit and T10 had no resident worker;
releasing a compile onto a partially reloaded fleet would violate the purpose
of the rollout hold.

## Q02 Admission Stop

The canonical first-Q02 read-only intake returned
`compile_work_item_not_done_compile_ok`. At
`2026-09-06T12:52:27.9643399Z`, five one-second whole-host CPU samples were
`97.170291`, `95.621858`, `96.777863`, `90.236504`, and `92.775522` percent.
Average utilization was `94.516408%` and maximum utilization was
`97.170291%`. Admission requires both average and maximum to be strictly below
`97%`; the maximum therefore binds. No Q02 work item was created.

Resume only after the worker rollout is complete, the governed compile becomes
`COMPILE_OK`, and a new five-sample CPU window clears the ceiling. Then use the
canonical first-Q02 intake bound to compile work item
`8b988156-b64e-4b12-aa5c-d5dc2a7d7438`.

## Safety Boundary

No `T_Live`, AutoTrading, portfolio gate, deploy manifest, live preset,
terminal restart, compiler-hold bypass, manual backtest, or priority boost was
touched.
