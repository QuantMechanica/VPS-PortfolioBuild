# FX cointegration frontier: current Q03 continuation / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T23:31:38Z`), 2026-08-24 Europe/Berlin

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
low-frequency, and has no ML or banned-indicator component. Its package
contains the required `basket_manifest.json`; the canonical backtest setfile
remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

A fresh supported `farmctl work-items --ea QM5_20219` read returned exactly
three lineage rows:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE/PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  `attempt_count=0`.
- Legacy Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed,
  `attempt_count=0`.

The exact Q03 successor is already present once, so enqueueing, requeueing,
reprioritising, or dispatching a second copy would be duplicate work.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-23T23:30:48Z`
observed four governed factory terminals actively testing: T1, T3, T4, and
T5. The paced launch maximum in
`D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`; current factory use is
therefore four times the allowed launch capacity. Every process was path- and
work-item-bound, with no orphaned terminal process reported.

The four usable one-second total-processor readings returned by the current
sample were `100%`, `100%`, `100%`, and `100%`. Both the average and maximum
were `100%`, above the explicit `97%` hard ceiling. `T_Live` and the unrelated
FTMO terminal were observed only to exclude them from the factory count;
neither was controlled.

Per the mission stop condition, no card or EA creation, compile, build check,
queue mutation, dispatch tick, tester launch, reservation, terminal control,
or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q03_pending_hard_cpu_stop_20260823T233138Z_board_advisor.json`.

## Non-duplicate delta

The immediately preceding frontier receipt could not assert a fresh terminal
roster because `farmctl` was unavailable on that shell's PATH. This snapshot
uses the supported repository-local command and proves four current,
path-bound factory tests while reconfirming the exact QM5_20219 Q03 row is
still pending once.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
