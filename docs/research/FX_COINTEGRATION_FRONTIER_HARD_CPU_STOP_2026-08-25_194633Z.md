# FX cointegration frontier: seven-terminal hard CPU stop

**Date:** 2026-08-25 UTC (`2026-08-25T19:46:33Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Observation base:** `ee49f833dff8eb110503dff08373881e444943cc`

**Status:** no non-duplicate unbuilt scan pair; stopped at the explicit
backtest CPU ceiling before any queue mutation

## Outcome

No Strategy Card or EA was created. The durable sign-aware relationship audit
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the governed scan: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

Fresh supported `farmctl work-items` queries reconfirmed that the preferred
anchors do not need Q02 infrastructure repair. `QM5_12532` has canonical Q02
PASS followed by Q04 PASS and Q05 FAIL. `QM5_12533` has canonical Q02 PASS
followed by Q04 FAIL. Neither has a current Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The selected nonterminal fallback remains frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`.
A fresh supported query returned exactly three rows:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE / PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  zero attempts.
- Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed,
  zero attempts.

The package is structural fixed-beta D1, low-frequency, contains
`basket_manifest.json`, and its backtest setfiles keep `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The unique Q03 successor was left
intact; no duplicate enqueue or priority mutation was made.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-25T19:46:20Z`
observed seven governed factory terminals actively testing: T3, T4, T6, T7,
T8, T9, and T10. All ten terminal-worker daemons were present, seven
reservations were active, and no orphaned factory terminal was reported.

Five fresh one-second whole-host CPU readings were `100.00%`, `98.34%`,
`99.32%`, `98.00%`, and `99.51%`. Their average was `99.03%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; both measures triggered the stop. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them from the factory
count; neither was controlled.

Per the mission stop condition, no card, EA, compile, build check, queue
mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T194633Z_board_advisor.json`.

## Non-duplicate operational delta

The preceding FX receipt at `2026-08-25T18:47:30Z` observed eight active
factory terminals and eight reservations, with average CPU `96.61%`. The
current supported census records seven active terminals and reservations;
T2 is no longer active, while the remaining seven are a different in-flight
cohort. Average CPU rose to `99.03%` and the maximum remains `100.00%`.
This receipt captures that changed governed occupancy and fresh capacity
measurement while reconfirming the single QM5_20219 Q03 lineage without
adding another work item.

## Safety and worktree hygiene

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row changed.
- Concurrent unrelated worktree changes were preserved and are excluded from
  this commit.
