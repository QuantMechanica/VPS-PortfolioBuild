# FX cointegration frontier: expanded six-terminal hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T12:16:53Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `a68786851d1107c67b5badb5985f5e424fd38dc7`

Status: no reputable, non-duplicate unbuilt frozen-scan pair; both preferred
anchors are past Q02; the one nonterminal existing FX fallback already has its
Q03 successor; stopped at the explicit backtest CPU ceiling

## Governed pair decision

The bounded OWNER-requested source
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely. Its
66-pair scan admits only `AUDUSD.DWX` / `NZDUSD.DWX` and `EURJPY.DWX` /
`GBPJPY.DWX` under the stated reputable-source criteria. Both already have
approved cards and built basket EAs as `QM5_12532` and `QM5_12533`. The durable
sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 frozen relationships, with zero uncovered. Creating a new
scan-derived identity would therefore duplicate governed work or promote a row
that failed the admitted evidence bar.

Fresh supported work-item queries confirm that the preferred anchors do not
need Q02 infrastructure repair. `QM5_12532` has a terminal logical-basket Q02
PASS and Q04 PASS before Q05 FAIL. `QM5_12533` has a terminal logical-basket
Q02 PASS before Q04 FAIL. Neither has a current Q02 ONINIT or NO_HISTORY
blocker.

## Existing-pair fallback

The concrete nonterminal fallback remains `QM5_20219_usdjpy-nzdusd`
(`USDJPY.DWX` / `NZDUSD.DWX`), a structural fixed-beta D1 basket. A fresh
canonical query returned exactly three rows: Q02
`5eb61981-472e-4f08-82c0-53fbec77d6c8` is DONE/PASS; Q03
`4514a6c7-0a2e-4523-a756-b63a232dd8aa` is PENDING, unclaimed, and has zero
attempts; and the older Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513` is also
PENDING, unclaimed, and has zero attempts. The Q03 successor therefore already
exists exactly once in the paced canonical queue. A second enqueue would be a
duplicate, and a manual runner would bypass the governed funnel.

Its existing contract remains low-frequency, structural, non-ML, and
fixed-risk for backtest. No Strategy Card, EA source, binary, setfile,
`basket_manifest.json`, registry row, magic row, or mechanics changed.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-26T12:16:29Z` observed
six governed factory terminals actively testing: T1, T4, T5, T7, T8, and T9.
Ten terminal-worker daemons were alive, seven reservations were active, and no
orphaned factory terminal process was reported. `T_Live` and the unrelated
FTMO terminal were observed only to exclude them; neither was controlled. The
paced launch gate remained `1`.

Five fresh one-second whole-host CPU readings were `99.90%`, `99.90%`,
`100.00%`, `99.72%`, and `100.00%`. Their average was `99.90%` and their
maximum was `100.00%`. The explicit ceiling binds when either the average or
maximum is at least `97%`; both measures triggered the stop.

Per the mission stop condition, no card or EA creation, registry or magic
mutation, compile, build check, queue mutation, dispatch tick, tester launch,
terminal reservation, terminal control, or backtest followed. Machine-readable
evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T121653Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt observed four factory terminals (T1, T7, T8, and T9)
and stopped before refreshing the fallback queue. This receipt records an
expanded, rotated six-terminal cohort and freshly seals the exact nonterminal
QM5_20219 lineage. It does not duplicate a pair, card, EA, or pipeline work
item.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
