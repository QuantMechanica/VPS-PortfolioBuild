# FX cointegration post-reboot CPU-ceiling stop

Date: 2026-09-11

Captured: `2026-09-11T20:16:25.3501019Z`

Branch: `agents/board-advisor`

Observation head: `d0e0fc52417e3fe932c04440ca7bd10078c9b118`

## Outcome

No new Strategy Card or basket EA was created. The frozen sign-aware FX
cointegration scan is already fully represented, so another scan-derived pair
would duplicate governed work. The preferred anchors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` passed logical-basket Q02 in work item
  `e4890d77-b865-4a48-b946-315faefca920`, passed Q04, and later failed Q05.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` passed logical-basket Q02 in work
  item `76cb11ee-7e9d-4d75-be9d-626c205bca62` and later failed Q04.

The existing-card fallback had already been performed for `QM5_11051` before
this observation. Its target `GBPUSD.DWX` D1 Q02 row
`97c5fffa-691b-407a-8a5f-363197037048` remains pending, unclaimed, and at
attempt zero. This run did not create a duplicate row or change its metadata.

## Binding CPU stop

The first whole-host admission sample reached `100%`; the next valid sample was
`99.529%`. Both exceeded the binding `97%` ceiling. A later diagnostic sample
fell below the ceiling, but the explicit mission rule says to stop once the
backtest CPU ceiling is hit; it does not authorize waiting for a transient dip
and then enqueuing.

Six factory tester processes were observed after the orchestrator census-cap
rollback: `T1`, `T3`, `T4`, `T5`, `T6`, and `T7`. `T_Live` was observed only to
exclude it and was not controlled. This is a materially different capacity
snapshot from the earlier four-terminal stop at 19:30Z.

Accordingly, no Q02 enqueue, dispatch tick, tester launch, terminal control, or
database mutation was performed.

## PACER build guard and safety

- No `.mq5` was generated or modified, so the mandatory post-write
  `audit_framework_input_pins.py --check-source` boundary was not entered.
- No compile command or compile enqueue was attempted.
- No Strategy Card, EA, binary, setfile, basket manifest, registry, or magic row
  changed.
- No portfolio-admission, KPI, Q08-contribution, portfolio-gate, deploy
  manifest, `T_Live`, or AutoTrading surface was touched.
- Existing unrelated staged and unstaged worktree changes were left untouched.

Machine-readable receipt:
`artifacts/fx_cointegration_cpu_ceiling_stop_20260911T201625Z_board_advisor.json`.
