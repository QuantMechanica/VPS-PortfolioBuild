# FX cointegration frontier: paced-fleet hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T18:16:25Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `2bcd0f708c5dafb1b753aae673fa62481d077ffe`

Status: frozen 66-pair frontier remains exhausted; anchor Q02 repair remains
inapplicable; stopped at the explicit backtest CPU ceiling

## Frontier and anchor decision

The preceding committed FX receipt,
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T173051Z_board_advisor.json`,
preserves the governed 66-of-66 relationship audit against
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. It leaves no reputable,
non-duplicate unbuilt scan pair. Creating another card or EA would duplicate an
existing governed relationship or relax the frozen scan criteria.

Neither requested anchor has the conditional Q02 blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

There is no current `ONINIT` or `NO_HISTORY` repair to make for either anchor.

## Existing-pair fallback observation

Fresh supported `farmctl mt5-slots` evidence at `2026-08-26T18:16:20Z` shows
the existing USDJPY/NZDUSD basket
`QM5_20219_USDJPY_NZDUSD_COINTEGRATION_D1` active at Q03 on T6 under work item
`4514a6c7-0a2e-4523-a756-b63a232dd8aa`. The paced fleet is already advancing
this eligible fallback, so no duplicate successor was inserted and its terminal
was not controlled.

This is a material change from the 17:30Z receipt, which observed
`QM5_20212_GBPUSD_EURJPY_COINTEGRATION_D1` at Q03 on T6.

## Binding capacity stop

The same snapshot reported four governed factory terminals actively testing:
T6, T7, T9, and T10. Ten terminal-worker daemons were alive, four terminal
reservations were active, three `metatester64` processes were present, and no
orphaned factory terminal process was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

Five fresh one-second whole-host CPU readings were `100.0%`, `100.0%`,
`100.0%`, `99.71%`, and `100.0%`. Their average was `99.94%` and their maximum
was `100.0%`, so both measures exceed the binding 97% average-or-maximum
ceiling.

Per the mission stop condition, no card, EA, registry, magic, compile, build
check, queue, priority, dispatch, reservation, terminal, tester, or backtest
mutation followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T181625Z_board_advisor.json`.

## Non-duplicate delta and safety

Relative to the 17:30Z FX receipt, T2 and T5 are no longer active and the T6 FX
work changed from QM5_20212 to QM5_20219. The factory test count fell from six
to four while the fresh CPU sample remained saturated at a 99.94% average.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
