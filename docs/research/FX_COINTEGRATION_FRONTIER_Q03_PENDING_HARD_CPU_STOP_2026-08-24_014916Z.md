# FX cointegration frontier: current Q03 continuation / hard CPU stop

**Date:** 2026-08-24 UTC (`2026-08-24T01:49:16Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier remains fully mechanized; the exact
existing FX continuation remains pending once at Q03; stopped at both paced
launch capacity and the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by
`analyze_cross_asset_v3.py --include-negative-hedges`: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The preferred anchors do not need Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS, followed
  by Q04 FAIL.

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The current nonterminal scan continuation remains rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as
`QM5_20219_usdjpy-nzdusd`. It is OWNER-approved, structural fixed-beta D1,
low-frequency, and contains no ML or banned-indicator component. Its package
contains the required `basket_manifest.json`; the canonical backtest setfile
remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Two supported `farmctl work-items` retries encountered the farm's active
SQLite writer and returned `sqlite3.OperationalError: database is locked`.
A query-only SQLite connection (`mode=ro`) then reconfirmed the exact current
lineage without mutating the queue:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE/PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  `attempt_count=0`.
- Legacy Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed,
  `attempt_count=0`.

The exact Q03 successor is already present once, so enqueueing, requeueing,
reprioritising, or dispatching a second copy would be duplicate work.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-24T01:49:17Z`
observed two governed factory terminals actively testing: T3 and T6. The
paced launch maximum in `D:/QM/strategy_farm/state/launch_gate_max.txt` is
`1`; current factory use was therefore twice the allowed launch capacity.
Both processes were path- and work-item-bound, with no orphaned terminal
process reported.

Five current whole-host CPU readings were `83.5127%`, `98.3147%`,
`100.0000%`, `99.0660%`, and `86.4447%`. Their average was `93.4676%` and
their maximum was `100.0000%`. The explicit ceiling binds when either the
average or maximum is at least `97%`; the maximum therefore triggered the
required stop. `T_Live` and the unrelated FTMO terminal were observed only to
exclude them from the factory count; neither was controlled.

Per the mission stop condition, no card or EA creation, compile, build check,
queue mutation, dispatch tick, tester launch, reservation, terminal control,
or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q03_pending_hard_cpu_stop_20260824T014916Z_board_advisor.json`.

## Non-duplicate delta

The preceding receipt observed T1, T3, T4, and T5 at the ceiling. This fresh
snapshot observes a changed, fully attributed roster (T3 and T6), independently
reconfirms the exact QM5_20219 lineage through a query-only fallback while the
supported view is writer-locked, and records the new binding CPU sample.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
