# FX cointegration frontier: rotated four-slot hard CPU stop

Date: 2026-08-25 UTC (`2026-08-25T23:31:58Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `1234b51bea279fa104e97062ea9459e4f8b1bd44`

Status: no non-duplicate unbuilt scan pair; stopped at the explicit backtest
CPU ceiling before any card, build, compile, queue, dispatch, or tester action

## Outcome

The bounded source result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` admitted only the two
original strict survivors. The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships: 66 covered and zero uncovered. A new
scan-derived identity would either duplicate governed work or weaken the
mission's reputable-source criterion.

Fresh supported farm queries reconfirmed that the preferred anchors are not
blocked at Q02. `QM5_12532` has logical-basket Q02 PASS, then Q04 PASS and Q05
FAIL. `QM5_12533` has logical-basket Q02 PASS, then Q04 FAIL. Neither has a
current ONINIT or NO_HISTORY repair target.

## Existing-pair fallback

The selected nonterminal fallback remains frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`.
The fresh `farmctl work-items --ea QM5_20219` query returned exactly three
rows:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE / PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed, zero attempts.
- Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed, zero attempts.

The unique Q03 successor already expresses the non-duplicate next action, so
no enqueue, requeue, priority restamp, or competing work item was valid. Its
approved package remains a structural fixed-beta D1 two-leg basket with
`basket_manifest.json`, no ML or banned indicator, and the backtest contract
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Binding capacity stop

Five fresh one-second whole-host CPU readings were `100%`, `100%`, `100%`,
`99%`, and `100%`. Their average was `99.8%` and their maximum was `100%`.
The explicit ceiling binds when either measure is at least `97%`; both measures
required an immediate stop.

The supported `farmctl mt5-slots` snapshot at `2026-08-25T23:31:52Z` saw four
governed factory terminals actively testing: T4, T6, T7, and T8. Four matching
reservations and all ten terminal-worker daemons were present, with no orphaned
factory terminal. `T_Live` and the unrelated FTMO terminal were observed only
to exclude them from the factory count; neither was controlled.

Per the mission stop condition, no card or EA creation, compile, build check,
queue mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T233158Z_board_advisor.json`.

## Non-duplicate operational delta

The preceding FX receipt at `2026-08-25T22:46:56Z` observed T2, T4, T7, and T9.
The current four-terminal roster contains T4, T6, T7, and T8: T2 and T9 left,
while T6 and T8 joined. Average CPU rose from `99.5%` to `99.8%`, while the
maximum remained `100%`. This rotated occupancy is the durable delta; the
single QM5_20219 Q03 lineage was reconfirmed without adding another work item.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this receipt.
