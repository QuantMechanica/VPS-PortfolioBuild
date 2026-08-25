# FX cointegration frontier: refreshed Q03 lineage hard CPU stop

**Date:** 2026-08-25 UTC (`2026-08-25T17:16:13Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Observation base:** `20dc75886cef0dc2996c0214eac68d61acb2c252`

**Status:** no non-duplicate unbuilt scan pair; the exact existing FX
continuation remains queued once; stopped at the explicit backtest CPU ceiling

## Outcome

No Strategy Card or EA was created. The durable sign-aware relationship audit
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the governed scan: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The preferred anchors do not need Q02 infrastructure repair. Fresh supported
`farmctl work-items` queries confirm:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS, Q04 PASS,
  and terminal Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS and
  terminal Q04 FAIL.

Neither anchor has a current canonical Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The nonterminal FX continuation remains frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as
`QM5_20219_usdjpy-nzdusd`. Its approved package is structural fixed-beta D1,
low-frequency, contains `basket_manifest.json`, and keeps
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The fresh lineage query returns exactly three rows:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE/PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  zero attempts.
- Preexisting Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING,
  unclaimed, zero attempts.

The Q03 successor already exists exactly once. Enqueueing, requeueing,
reprioritising, or dispatching a second copy would be duplicate work.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-25T17:16:07Z`
observed five governed factory terminals actively testing: T4, T6, T7, T8,
and T9. All ten terminal-worker daemons were present, six reservations were
active, and `D:/QM/strategy_farm/state/launch_gate_max.txt` remained `1`.

Five fresh one-second whole-host CPU readings were `99.82%`, `99.91%`,
`100.00%`, `100.00%`, and `100.00%`. Their average was `99.95%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; both measurements triggered the stop. `T_Live` and
the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled.

Per the mission stop condition, no card, EA, compile, build check, queue
mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T171613Z_board_advisor.json`.

## Non-duplicate operational delta

The preceding FX receipt at `2026-08-25T16:17:13Z` saw T1, T4, T6, T7, and
T9, with average CPU `94.96%`. The current supported census instead sees T4,
T6, T7, T8, and T9, with average CPU `99.95%`; T1 left and T8 joined while
the maximum remained `100.00%`. The unique QM5_20219 Q03 row remains
untouched.

## Safety and worktree hygiene

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were preserved and are excluded from
  this commit.
