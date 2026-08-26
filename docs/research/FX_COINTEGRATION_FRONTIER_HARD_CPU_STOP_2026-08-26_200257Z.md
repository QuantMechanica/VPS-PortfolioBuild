# FX cointegration frontier: Q03 active / hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T20:02:57Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `83f840ffcb12a2ddacd0e6b5fe7fa8d08c730827`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; the existing FX fallback is already active
at Q03 with its Q04 successor pending; stopped at the explicit backtest CPU
ceiling

## Frontier and anchor decision

The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. A new scan-derived Strategy Card or EA would duplicate governed
work or relax the reputable-source boundary.

Fresh supported `farmctl work-items --ea` queries confirm that the requested
anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has a current `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Existing-pair fallback

`QM5_20220_USDCAD_AUDJPY_COINTEGRATION_D1` remains active at Q03 on T4 under
work item `2e797aa8-42ef-479e-875f-da93436ca528`. Its Q02 work item
`61e7d1af-35a2-48f4-8602-afcf94949118` is terminal PASS, and Q04 work item
`0961cfd5-4831-4ef9-bf5b-cab4bfcab089` is already pending. Inserting another
Q02, Q03, or Q04 row would therefore be duplicate work.

The existing build preserves the requested structural controls: an approved
Tier-A Chan-sourced card, fixed-beta low-frequency D1 mechanics, no ML, a
`basket_manifest.json`, and a backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-26T20:01:48Z`
observed seven governed factory terminals actively testing: T1, T2, T4, T5,
T7, T9, and T10. All ten terminal-worker daemons were alive, seven terminal
reservations were active, and no orphaned factory terminal process was
reported. `T_Live` and the unrelated FTMO terminal were observed only to
exclude them; neither was controlled.

Five fresh whole-host CPU readings from `20:02:47Z` through `20:02:57Z` were
100%, 96%, 99%, 88%, and 100%. Their average was 96.6% and their maximum was
100%. The binding ceiling applies when either the average or maximum reaches
97%; the maximum triggered the stop. The factory terminal count was also
exactly at the seven-terminal mission ceiling, while the paced launch gate
remained `1`.

Per the mission stop condition, no Card, EA, registry, magic, compile, build
check, queue, priority, dispatch, reservation, terminal, tester, or backtest
mutation followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T200257Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt at `2026-08-26T19:19:46Z` observed eight active
factory terminals. This receipt records a changed fleet state: seven are now
active, the maximum CPU reading remains at the hard ceiling, and the existing
FX fallback has a Q04 successor already pending behind its active Q03 row.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from
  this receipt.
