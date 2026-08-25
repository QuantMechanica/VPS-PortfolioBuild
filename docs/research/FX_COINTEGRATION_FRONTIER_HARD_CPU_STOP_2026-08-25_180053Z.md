# FX cointegration frontier: unchanged roster / hard CPU stop

**Date:** 2026-08-25 UTC (`2026-08-25T18:00:53Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Observation base:** `d7f67fd47ab95ff47301ecb21db87fe332cbfa01`

**Status:** no non-duplicate unbuilt scan pair; stopped at the explicit
backtest CPU ceiling before any queue mutation

## Outcome

No Strategy Card or EA was created. The durable sign-aware relationship audit
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the governed scan: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The most recent fresh lineage receipt,
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T171613Z_board_advisor.json`,
also established that the preferred anchors do not need Q02 infrastructure
repair: `QM5_12532` has canonical Q02 PASS followed by Q04 PASS and Q05 FAIL,
while `QM5_12533` has canonical Q02 PASS followed by Q04 FAIL. Neither had a
current Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The selected nonterminal fallback remains frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`.
The preceding receipt verified one Q02 PASS and exactly one pending Q03
successor (`4514a6c7-0a2e-4523-a756-b63a232dd8aa`), plus one preexisting
pending Q04 row. The package is structural fixed-beta D1, low-frequency,
contains `basket_manifest.json`, and keeps `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No fresh lineage query or enqueue followed the capacity sample. The existing
successor was left untouched rather than risking a duplicate.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-25T18:00:48Z`
observed five governed factory terminals actively testing: T4, T6, T7, T8,
and T9. All ten terminal-worker daemons were present, five reservations were
active, and no orphaned factory terminal was reported.

Five fresh one-second whole-host CPU readings were `100.00%`, `100.00%`,
`100.00%`, `99.33%`, and `99.81%`. Their average was `99.83%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; both measurements triggered the stop. `T_Live` and
the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled.

Per the mission stop condition, no card, EA, compile, build check, queue
mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T180053Z_board_advisor.json`.

## Non-duplicate operational delta

The preceding FX receipt at `2026-08-25T17:16:13Z` observed the same five
factory terminals but six active reservations and average CPU `99.95%`.
The current supported census records five active reservations and average CPU
`99.83%`; the maximum remains `100.00%`. This receipt records the changed
reservation census without adding another work item.

## Safety and worktree hygiene

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row changed.
- Concurrent unrelated worktree changes were preserved and are excluded from
  this commit.
