# FX cointegration frontier: refreshed-lineage hard CPU stop

**Date:** 2026-08-25 UTC (`2026-08-25T16:17:13Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Observation base:** `572f2c0f187bcedd5d6a2b556f8dc02a3c73bb62`

**Status:** no non-duplicate unbuilt scan pair; the exact existing FX
continuation remains queued once; stopped at the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the governed scan: 66 covered
and zero uncovered. Creating another scan-derived identity would duplicate
governed work.

The preferred anchors do not need Q02 infrastructure repair. A fresh supported
`farmctl work-items` query confirms:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS, Q04 PASS,
  and terminal Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS and
  terminal Q04 FAIL.

Neither anchor has a current canonical Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The latest durable frontier selected frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`, as
the exact nonterminal FX continuation. Its approved package remains structural
fixed-beta D1, low-frequency, contains `basket_manifest.json`, and keeps
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The fresh lineage query confirms Q02
`5eb61981-472e-4f08-82c0-53fbec77d6c8` DONE/PASS and exactly one Q03
successor, `4514a6c7-0a2e-4523-a756-b63a232dd8aa`, PENDING, unclaimed, with
zero attempts. A preexisting Q04 row,
`b721ce82-2d53-46db-b2d0-f20b561a1513`, is also PENDING; it dates from
2026-08-05 and was not changed. Adding another Q02 or Q03 row would be
duplicate work.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-25T16:17:13Z`
observed five governed factory terminals actively testing: T1, T4, T6, T7,
and T9. All ten terminal-worker daemons were present, six reservations were
active, and the paced launch gate in
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`.

Five fresh one-second whole-host CPU readings were `100.00%`, `99.91%`,
`93.23%`, `91.31%`, and `90.33%`. Their average was `94.96%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; the maximum therefore triggered the stop. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled.

Per the mission stop condition, no card, EA, compile, build check, queue
mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T161713Z_board_advisor.json`.

## Non-duplicate operational delta

The prior `2026-08-25T14:32:14Z` receipt observed seven factory MT5 children,
ten worker daemons, and eight active reservations, with average CPU `99.90%`.
The current supported census instead sees five factory MT5 children, the same
ten workers, six reservations, and average CPU `94.96%`; a `100.00%` sample
still binds the ceiling. The fresh lineage query also verifies that the one
Q03 successor remains untouched rather than being duplicated.

## Safety and worktree hygiene

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were preserved and are excluded from
  this commit.
