# FX cointegration frontier: existing-pair Q03 / hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T19:19:46Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `8a7618234776934dab222c62075e1225de1138bb`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; the paced fleet is already advancing one
existing FX basket at Q03; stopped at the explicit backtest CPU ceiling

## Frontier and anchor decision

The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. A new scan-derived Strategy Card or EA would duplicate governed
work or relax the reputable-source boundary.

The requested anchors remain past Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has a current `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Existing-pair fallback

The supported `farmctl mt5-slots` snapshot at `2026-08-26T19:17:40Z`
observed `QM5_20220_USDCAD_AUDJPY_COINTEGRATION_D1` active at Q03 on T4
under work item `2e797aa8-42ef-479e-875f-da93436ca528`. This existing,
dedicated low-frequency D1 basket already has its approved Card, compiled EA,
logical fixed-risk backtest setfile, and `basket_manifest.json` in the
repository. The canonical factory is therefore already advancing the eligible
fallback beyond Q02. No duplicate Q02 or Q03 row was inserted.

## Binding capacity stop

The same supported snapshot reported eight governed factory terminals
actively testing: T1, T2, T4, T5, T6, T7, T9, and T10. All ten terminal-worker
daemons were alive, eight terminal reservations were active, and no orphaned
factory terminal process was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

Five fresh whole-host CPU readings taken from `2026-08-26T19:19:40Z` through
`19:19:46Z` were `100%`, `99%`, `100%`, `100%`, and `100%`. Their average was
`99.8%` and their maximum was `100%`. Both exceed the binding 97% average-or-
maximum ceiling, while the eight active factory terminals also exceed the
seven-terminal mission ceiling.

Per the mission stop condition, no Card, EA, registry, magic, compile, build
check, queue, priority, dispatch, reservation, terminal, tester, or backtest
mutation followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T191946Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt at `2026-08-26T18:16:25Z` observed four factory
terminals and `QM5_20219` at Q03. This receipt records a changed frontier
state: eight factory terminals are active and the governed FX Q03 lane has
advanced to `QM5_20220`.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from
  this receipt.
