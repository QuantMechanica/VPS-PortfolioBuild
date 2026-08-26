# FX cointegration frontier: seven-tester hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T09:16:03Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `74ab4e6d67fecfc128f13173ed1a6d2068c52aad`

Status: no reputable, non-duplicate unbuilt frozen-scan pair; both preferred
anchors are past Q02; stopped at the explicit backtest CPU ceiling before any
card, build, queue, dispatch, compile, or tester action

## Governed pair decision

The bounded OWNER-requested result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely. It
admits only two strict scan survivors: `AUDUSD.DWX` / `NZDUSD.DWX` and
`EURJPY.DWX` / `GBPJPY.DWX`. They are already carded and built as `QM5_12532`
and `QM5_12533`; the source rejects or declines to card its other tested FX,
triangular, and cross-asset forms.

The durable sign-aware audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 frozen relationships: 66 covered and zero uncovered. A new
scan identity would duplicate governed work, while carding a rejected or weak
row would fail the reputable-source criterion.

The preferred anchors require no Q02 repair. Durable evidence has `QM5_12532`
at Q02 PASS and Q04 PASS before Q05 FAIL, and `QM5_12533` at Q02 PASS before
Q04 FAIL. Neither has an ONINIT or NO_HISTORY Q02 blocker.

## Existing-pair fallback

The last durable selection is frozen-scan rank 40, `USDJPY.DWX` /
`NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`. The preceding receipt
records Q02 PASS and exactly one unique Q03 successor pending. The CPU ceiling
bound before a fresh queue query, so no duplicate enqueue, requeue, or priority
mutation was attempted.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-26T09:15:27Z` observed
seven governed factory terminals actively testing: T1, T3, T4, T6, T7, T8,
and T9. `T_Live` was observed only to exclude it and was not controlled.

Five fresh one-second whole-host CPU readings were `95.54%`, `100.00%`,
`100.00%`, `100.00%`, and `100.00%`. Their average was `99.11%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; both measures triggered the stop. Seven
`metatester64` processes were present at the end of the sample.

Per the mission stop condition, no further candidate search, Strategy Card or
EA creation, registry or magic mutation, compile, build check, queue mutation,
dispatch tick, tester launch, terminal reservation, terminal control, or
backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T091603Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt sampled a `99.66%` average, `100.00%` maximum, and six
tester processes. This sample has one additional active factory terminal and
tester process while remaining hard-saturated. It records changed fleet
capacity without duplicating a pair or pipeline row.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
