# FX cointegration frontier: occupied-fleet hard CPU stop

**Date:** 2026-08-25 UTC (`2026-08-25T14:32:14Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Observation base:** `774f6fab033576b4f6abbb8d39fc967f09dbbafb`

**Status:** no non-duplicate unbuilt scan pair; the exact existing FX
continuation was left untouched; stopped at the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the governed scan: 66 covered
and zero uncovered. Creating another scan-derived identity would duplicate
governed work.

The preferred anchors do not need Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS and later reached
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS and later
  reached Q04 FAIL.

Neither anchor has a current durable Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The latest durable lineage identifies frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`, as the
exact nonterminal FX continuation. Its approved package is structural
fixed-beta D1, low-frequency, contains `basket_manifest.json`, and keeps the
logical backtest contract at `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The last durable view records Q02
`5eb61981-472e-4f08-82c0-53fbec77d6c8` as DONE/PASS and Q03
`4514a6c7-0a2e-4523-a756-b63a232dd8aa` as PENDING, unclaimed, with zero
attempts. That Q03 successor already exists exactly once. The current run hit
the CPU ceiling before a fresh lineage query, so it made no duplicate enqueue,
requeue, reprioritisation, dispatch, or legacy-row mutation.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-25T14:31:06Z`
observed seven governed factory terminals actively testing: T1, T2, T3, T4,
T6, T9, and T10. All ten terminal-worker daemons were present and eight
factory reservations were active. The paced launch gate in
`D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`.

Five fresh one-second whole-host CPU readings were `100.00%`, `99.90%`,
`99.81%`, `100.00%`, and `99.81%`. Their average was `99.90%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; both measures triggered the stop. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them from the factory
count; neither was controlled.

Per the mission stop condition, no card, EA, compile, build check, queue
mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T143214Z_board_advisor.json`.

## Non-duplicate operational delta

The prior `2026-08-24T13:12:23Z` receipt observed zero MT5 children, zero
worker daemons, and three active factory reservations. The current supported
census instead sees seven governed MT5 children, all ten worker daemons, and
eight reservations. This changed fleet topology is the durable delta recorded
by this evidence-only commit; it does not create another strategy, work item,
or pipeline identity.

## Safety and worktree hygiene

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were preserved and are excluded from
  this commit.
