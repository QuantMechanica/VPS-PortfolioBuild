# FX cointegration frontier: active fallback / hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T07:32:43.8739689Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `1f6b0b43598410e1bf5474c3b0c0bb86c1716f35`

Status: the frozen 66-pair frontier remains fully mechanized; neither anchor
has a Q02 infrastructure blocker; an existing FX basket is already active at
Q03; stopped at the explicit backtest CPU ceiling before any build or queue
mutation

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

Neither anchor has an `ONINIT` or `NO_HISTORY` Q02 repair to perform.

## Existing-pair fallback

The supported slot snapshot found the already-built market-neutral basket
`QM5_20238_USDCAD_EURJPY_COINTEGRATION_D1` actively advancing through Q03 on
T9 under work item `dc7cadb3-f1f3-40a7-b6dc-d9b38b208223`. It was left
undisturbed. Enqueuing it again, or selecting another identity while this
governed fallback is active and capacity is binding, would be duplicate work.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-27T07:32:26Z`
observed four governed factory terminals actively testing: T2, T3, T6, and
T9. Four matching terminal reservations were active, and no orphaned factory
terminal process was reported. `T_Live` and the unrelated FTMO terminal were
observed only to exclude them from the factory count; neither was controlled.
The paced launch gate remained `1`.

Five fresh whole-host CPU readings were `87%`, `76%`, `79%`, `76%`, and
`99%`. Their average was `83.4%` and their maximum was `99%`. The binding rule
applies when either measure reaches `97%`; the maximum triggered the mission's
immediate stop condition.

The preceding fleet receipt at `2026-08-27T07:16:09Z` observed seven running
factory terminals and `99.6165%` average CPU. T4, T8, and T10 have since
cleared, reducing occupancy to four and average CPU to `83.4%`, while the
fresh maximum remains above the hard ceiling. This changed capacity topology
and the observed active Q03 FX fallback are fresh evidence, not a repeated EA
or queue insertion.

## Stop disposition and safety

Per the mission stop condition, no Card, EA, registry, magic, resolver,
compile, build check, smoke, queue, priority, dispatch, reservation, terminal,
tester, or backtest mutation followed. The active T9 fallback was not
interrupted.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, or basket manifest changed.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260827T073243Z_board_advisor.json`.
