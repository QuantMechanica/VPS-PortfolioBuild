# FX cointegration frontier: refreshed hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T17:30:51Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `c2ca91cefa18783895d239439bf4ad09c51deb83`

Status: frozen 66-pair frontier remains exhausted; anchor Q02 repair remains
inapplicable; stopped at the explicit backtest CPU ceiling

## Frontier and anchor decision

The immediately preceding committed FX receipt,
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T163117Z_board_advisor.json`,
records a complete 66-of-66 governed relationship audit against
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. It leaves no reputable,
non-duplicate unbuilt scan pair. Creating another card or EA would duplicate an
existing governed relationship or relax the frozen scan criteria.

That receipt also confirms that neither requested anchor has the conditional
Q02 blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

There is therefore no current `ONINIT` or `NO_HISTORY` repair to make for the
anchors. The recorded fallback `QM5_12778` already has Q02 PASS and one pending
governed compile successor, so another compile or Q02 enqueue would be a
duplicate.

## Existing-pair fallback observation

Fresh supported `farmctl mt5-slots` evidence at `2026-08-26T17:30:20Z` shows
the existing GBPUSD/EURJPY basket
`QM5_20212_GBPUSD_EURJPY_COINTEGRATION_D1` still active at Q03 on T6 under
work item `6455c1ea-5159-4a1c-92d0-b9ee3b0078f6`. The paced fleet is already
advancing this fallback, so no duplicate successor was inserted and its
terminal was not controlled.

## Binding capacity stop

The same snapshot reported six governed factory terminals actively testing:
T2, T5, T6, T7, T9, and T10. Eight terminal-worker daemons were alive, six
terminal reservations were active, six `metatester64` processes were present,
and no orphaned factory terminal process was reported. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

Five fresh one-second whole-host CPU readings were `100.0%`, `100.0%`,
`100.0%`, `99.9%`, and `100.0%`. Their average was `99.98%` and their maximum
was `100.0%`, so both measures exceed the binding 97% average-or-maximum
ceiling.

Per the mission stop condition, no card, EA, registry, magic, compile, build
check, queue, priority, dispatch, reservation, terminal, tester, or backtest
mutation followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T173051Z_board_advisor.json`.

## Non-duplicate delta and safety

Relative to the 16:31Z FX receipt, T1 and T4 are no longer active and T10 is
newly active; the factory test count fell from seven to six while the fresh CPU
sample remained saturated at a 99.98% average. `QM5_20212` remains the active
FX fallback on T6. This changed capacity state makes the receipt distinct
without adding duplicate governed work.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
