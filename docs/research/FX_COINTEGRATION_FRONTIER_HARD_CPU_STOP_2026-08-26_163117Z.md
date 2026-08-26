# FX cointegration frontier: existing-pair reconciliation / hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T16:31:17Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `71bf1feb1ffe6115e6637d4b1825cff63dbe6f3f`

Status: no reputable, non-duplicate unbuilt frozen-scan pair; no anchor Q02
repair required; selected fallback already has Q02 PASS and a pending governed
compile; stopped at the explicit backtest CPU ceiling

## Pair and anchor decision

The durable complete-source and 66-relationship coverage audit in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T154621Z_board_advisor.json`
still leaves no uncovered reputable-source identity. Creating another card or
EA would either duplicate an existing governed relationship or relax the
frozen scan's admission criteria.

The same canonical evidence shows that the two requested anchors are not
blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

Neither has a current `ONINIT` or `NO_HISTORY` Q02 defect to repair.

## Existing-pair fallback reconciliation

The selected fallback was the recently repaired AUDUSD/EURJPY basket
`QM5_12778_edgelab-audusd-eurjpy-cointegration`. Fresh canonical
`farmctl work-items` evidence shows that a Q02 enqueue would be a duplicate:
the logical basket has two Q02 PASS rows, the latest being
`462e2f78-8589-48eb-8bca-25c804b67bf8`, and later PASS evidence through Q07
plus Q10. Its structural MAE-hook repair is already committed as `904748f9c`,
and exactly one governed compile successor
(`3cf75022-91f6-413f-aa0e-dfe24a738c05`) remains pending. No second compile or
Q02 row was inserted.

The factory snapshot also shows that the paced fleet is already advancing the
existing GBPUSD/EURJPY basket `QM5_20212`: Q03 work item
`6455c1ea-5159-4a1c-92d0-b9ee3b0078f6` is active on T6. This was observed only;
the terminal and work item were not controlled or mutated.

## Binding capacity stop

At `2026-08-26T16:30:47Z`, the supported `farmctl mt5-slots` view reported
seven governed factory terminals actively testing: T1, T2, T4, T5, T6, T7,
and T9. Ten terminal-worker daemons were alive, seven terminal reservations
were active, and no orphaned factory terminal process was reported. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them; neither
was controlled.

Five fresh one-second whole-host CPU readings were `100.0%`, `100.0%`,
`99.9%`, `100.0%`, and `100.0%`. Their average was `99.98%` and their maximum
was `100.0%`. Both measures exceed the binding 97% average-or-maximum ceiling.

Per the mission stop condition, no card, EA, registry, magic, compile, build
check, queue, priority, dispatch, reservation, terminal, tester, or backtest
mutation followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260826T163117Z_board_advisor.json`.

## Non-duplicate delta and safety

The preceding FX receipt observed four active factory terminals (T2, T5, T7,
and T9), a 94.56% average CPU sample, and a 99.9% maximum. This receipt records
three newly active terminals (T1, T4, and T6), a near-saturated 99.98% average,
and the active Q03 advancement of `QM5_20212`. It also closes the tempting but
invalid `QM5_12778` Q02 fallback by documenting its existing PASS lineage and
already-pending compile successor.

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic
  row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this
  receipt.
