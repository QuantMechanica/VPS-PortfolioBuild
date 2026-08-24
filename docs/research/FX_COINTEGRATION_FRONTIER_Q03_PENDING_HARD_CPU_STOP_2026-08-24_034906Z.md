# FX cointegration frontier: seven-terminal hard CPU stop

**Date:** 2026-08-24 UTC (`2026-08-24T03:49:06Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Base commit:** `086903a366f0790f41d33caf6ab8788c4fbfe543`

**Status:** no non-duplicate unbuilt scan pair; the exact existing FX
continuation remains pending once at Q03; stopped at the explicit backtest CPU
ceiling with seven governed factory terminals already active

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

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The exact nonterminal scan continuation remains rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`.
Its approved package is structural fixed-beta D1, low-frequency, contains the
required `basket_manifest.json`, and keeps the logical backtest set at
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The supported work-item view reconfirmed its unchanged lineage:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE/PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  `attempt_count=0`.
- Legacy Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed,
  `attempt_count=0`.

The Q03 successor already exists exactly once. No duplicate enqueue, requeue,
reprioritisation, dispatch, or legacy-row mutation was made.

## Binding capacity stop

Five fresh one-second whole-host CPU readings were all `100%`; both the average
and maximum were `100%`, above the explicit `97%` hard ceiling. The paced
launch maximum remains `1`, while the supported MT5 process scan attributed
seven active factory terminals: T2, T3, T4, T6, T8, T9, and T10. Each was
bound to a current governed work item; no orphaned terminal was reported.

`T_Live` and the unrelated FTMO terminal were observed only to exclude them
from the factory count. Neither was controlled. Per the mission stop condition,
no compile, build check, queue mutation, dispatch, tester action, reservation,
or backtest followed.

This is a non-duplicate operational delta from the preceding `02:46:50Z`
receipt: the attributed factory roster expanded from two active terminals to
seven, the CPU average increased from `99.8%` to `100%`, and the unique
QM5_20219 Q03 lineage remained intact.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q03_pending_hard_cpu_stop_20260824T034906Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
