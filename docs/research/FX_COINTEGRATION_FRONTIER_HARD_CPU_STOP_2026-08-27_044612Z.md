# FX cointegration frontier: hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T04:46:12.7730343Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `7c77eb0b58975b953ad226fa31c7060558f82e6f`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; stopped at the explicit backtest CPU
ceiling before any candidate, queue, compile, or test mutation

## Frontier and anchor decision

The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. The published scan's only strict survivors are already built as
`QM5_12533` and `QM5_12532`. Creating another scan-derived Strategy Card or EA
would duplicate governed work or relax the reputable-source threshold.

The latest durable anchor evidence remains beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has an `ONINIT` or `NO_HISTORY` Q02 repair to perform. Because
the capacity preflight bound first, this turn did not select or query another
existing-pair fallback and did not insert a duplicate work item.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T04:45:49Z`
observed six governed factory terminals actively testing: T2, T5, T6, T7,
T8, and T9. Six terminal reservations were active, and no orphaned factory
terminal process was reported. `T_Live` and the unrelated FTMO terminal were
observed only to exclude them; neither was controlled.

Five fresh whole-host CPU readings ending at
`2026-08-27T04:46:12.7730343Z` were 100%, 100%, 100%, 100%, and 100%. Their
average and maximum were both 100%. The binding rule applies when either
measure reaches 97%; both triggered the mission's immediate stop condition.
The paced launch gate remained `1`.

Per the mission stop condition, no Card, EA, registry, magic, compile, build
check, queue, priority, dispatch, reservation, terminal, tester, or backtest
mutation followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T044612Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding capacity receipt at `2026-08-27T04:30:24Z` observed T1, T2, T5,
T6, T7, and T9. The current roster dropped T1 and added T8 while CPU rose from
99.2% average to 100%. This rotated governed factory state is fresh capacity
evidence, not a repeated queue insert.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from
  this evidence-only commit.
