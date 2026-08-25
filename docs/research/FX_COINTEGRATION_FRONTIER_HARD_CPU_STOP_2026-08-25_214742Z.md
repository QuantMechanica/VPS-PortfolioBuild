# FX cointegration frontier: seventh reservation / hard CPU stop

**Date:** 2026-08-25 UTC (`2026-08-25T21:48:06Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Observation base:** `b4c1128fd0a6ab8d566de0b5ffa08a0b7397b0b4`

**Status:** no non-duplicate unbuilt scan pair; stopped at the explicit
backtest CPU ceiling before any queue mutation

## Outcome

No Strategy Card or EA was created. The source result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` admits only the two
original survivors, and the durable sign-aware audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships: 66 covered and zero uncovered. Creating a
new scan-derived identity would duplicate governed work and would not meet the
card source-quality boundary.

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

Its approved card cites the OWNER-ratified Tier-A Ernest Chan pair-trading
method plus the frozen 66-pair scan. The package is structural fixed-beta D1,
low-frequency, includes `basket_manifest.json`, and its logical backtest
setfile keeps `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The unique Q03 successor was left intact; no duplicate
enqueue or priority mutation was made.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-25T21:47:36Z`
observed six governed factory terminals actively testing: T2, T5, T6, T7,
T8, and T9. All ten terminal-worker daemons were present, seven reservations
were active, and no orphaned factory terminal was reported. T4 had a new
reservation but no running terminal process at the snapshot boundary.

Five fresh one-second whole-host CPU readings were `100.00%`, `100.00%`,
`100.00%`, `100.00%`, and `99.91%`. Their average was `99.98%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; both measures triggered the stop. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them from the factory
count; neither was controlled.

Per the mission stop condition, no card, EA, compile, build check, queue
mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T214742Z_board_advisor.json`.

## Non-duplicate operational delta

The preceding FX receipt at `2026-08-25T20:46:33Z` observed six active
factory terminals and six reservations. The current supported census still
records six running terminals, but now records a seventh reservation on T4
awaiting a process. This changed governed occupancy is the durable delta; the
single QM5_20219 Q03 lineage remains unchanged and was not duplicated.

## Safety and worktree hygiene

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row changed.
- Concurrent unrelated worktree changes were preserved and are excluded from
  this commit.
