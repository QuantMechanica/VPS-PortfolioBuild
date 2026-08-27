# FX cointegration frontier: active fallback / hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T08:32:04.6258443Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `49e5d4b120ef8b47a6848394cc20cc7d8a1a4628`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; an existing FX basket is already active at
Q03; stopped at the explicit backtest CPU ceiling before any build or queue
mutation

## Frontier and anchor decision

The durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the frozen scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: 66 covered and zero
uncovered. The published scan has only two strict survivors, already built as
`QM5_12533` and `QM5_12532`. Another scan-derived Strategy Card or EA would
therefore duplicate governed work or relax the reputable-source threshold.

The anchors are beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither has an `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Existing-pair fallback

The supported slot snapshot found the already-built market-neutral basket
`QM5_20250_USDCHF_AUDJPY_COINTEGRATION_D1` actively advancing through Q03 on
T9 under work item `5a987bd1-b335-404f-85c9-e2406dadb806`. It was left
undisturbed. Enqueuing it again would duplicate worker-owned work.

This is a changed fallback state: the preceding FX receipt observed
`QM5_20238_USDCAD_EURJPY_COINTEGRATION_D1` at Q03; the governed lane has since
advanced to `QM5_20250`.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T08:31:11Z`
observed six governed factory terminals actively testing: T1, T3, T6, T7,
T8, and T9. Six matching terminal reservations were active, and no orphaned
factory terminal process was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them from the factory count; neither
was controlled.

Five fresh whole-host CPU readings were all `100%`. Average and maximum were
therefore both `100%`, above the `97%` hard ceiling. The mission's immediate
stop condition is binding.

Compared with the preceding FX receipt, T2 cleared while T1, T7, and T8
became active, raising factory occupancy from four to six; average CPU rose
from `83.4%` to `100%`. This fleet-topology change and the newly active FX
fallback make this a fresh handoff rather than a duplicate queue action.

## Stop disposition and safety

Per the mission stop condition, no Card, EA, registry, magic, resolver,
compile, build check, smoke, queue, priority, dispatch, reservation, terminal,
tester, or backtest mutation followed. The active T9 fallback was not
interrupted.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, or basket manifest changed.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T083111Z_board_advisor.json`.
