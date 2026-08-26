# FX cointegration frontier: rotated four-terminal hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T11:16:19Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `d4de8c65d18f69826ae142892fd975ae38c5c1b4`

Status: no reputable, non-duplicate unbuilt frozen-scan pair; both preferred
anchors are past Q02; stopped at the explicit backtest CPU ceiling before any
card, build, queue, dispatch, compile, or tester mutation

## Governed pair decision

The bounded OWNER-requested source
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely. Its
66-pair scan admits only `AUDUSD.DWX` / `NZDUSD.DWX` and `EURJPY.DWX` /
`GBPJPY.DWX`. Both already have approved cards and built basket EAs as
`QM5_12532` and `QM5_12533`. The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 frozen relationships, with zero uncovered. Creating
another scan-derived identity would duplicate governed work or promote a row
that failed the reputable-source admission bar.

The latest durable anchor evidence remains conclusive: `QM5_12532` has Q02
PASS and Q04 PASS before Q05 FAIL; `QM5_12533` has Q02 PASS before Q04 FAIL.
Neither anchor has an ONINIT or NO_HISTORY Q02 blocker to repair.

## Existing-pair fallback boundary

The last selected structural D1 fallback is `QM5_20219_usdjpy-nzdusd`
(`USDJPY.DWX` / `NZDUSD.DWX`). The immediately preceding durable receipt records
Q02 PASS, one pending Q03 row, and an older pending Q04 row. The CPU ceiling
bound before a fresh queue query, enqueue, requeue, priority mutation, dispatch,
or tester action, so no claim is made here that its runtime state remained
unchanged after that receipt.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-26T11:16:14Z` observed
four governed factory terminals actively testing: T1, T7, T8, and T9. Ten
terminal-worker daemons were alive, four reservations were active, and no
orphaned factory terminal process was reported. `T_Live` and the unrelated
FTMO terminal were observed only to exclude them; neither was controlled. The
paced launch gate remained `1`.

Five fresh one-second whole-host CPU readings were `100.00%`, `100.00%`,
`99.80%`, `99.80%`, and `100.00%`. Their average was `99.92%` and their maximum
was `100.00%`. The explicit ceiling binds when either the average or maximum is
at least `97%`; both measures triggered the stop. Four `metatester64` processes
were present at sample completion.

Per the mission stop condition, no further Strategy Card or EA creation,
registry or magic mutation, compile, build check, queue mutation, dispatch
tick, tester launch, terminal reservation, terminal control, or backtest
followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T111619Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt observed five factory terminals (T2, T3, T4, T7, and
T9), 89.62% average CPU, and a 99.62% peak. This receipt records a rotated,
contracted four-terminal cohort and sustained saturation at 99.92% average / a
100% peak. It does not duplicate a pair, card, EA, or pipeline enqueue.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
