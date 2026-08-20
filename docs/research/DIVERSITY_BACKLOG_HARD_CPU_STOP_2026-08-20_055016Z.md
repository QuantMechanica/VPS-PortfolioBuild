# Diversity build backlog — hard CPU-ceiling stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Status: stopped before claim, build, smoke, or Q02 enqueue because the explicit
backtest CPU ceiling is binding

## Outcome

No EA was claimed or changed. A read-only farm snapshot found 35 pending
`build_ea` tasks covering 34 distinct EAs, and every task's target EA directory
already contains an `.mq5`. The pending queue is therefore a rework/defer queue,
not a virgin-card build queue. Creating or rebuilding an EA without first
resolving its current ownership would risk colliding with the paced fleet.

The deterministic strategy-priority scorer ranked `QM5_11735_rfs-psar-cci-ema-m5`
highest among those pending rows, but it is an existing M5 indicator-stack EA,
not a low-frequency new structural build. Two closer mission fits are also not
safe fresh claims: `QM5_12599_wti-feb-prem` is an existing D1 WTI seasonal
review-rework with three work items and an explicit Q02-handoff claim purpose;
`QM5_11294_cs-ichi-cloud` is an existing H4 FX build already claimed by
`codex`, with Q01 passed and Q02 deferred at an earlier CPU ceiling.

The global approved-card scorer's top unbuilt names were not substituted into
the queue. The shared worktree already contains peer-agent artifacts for
`QM5_36005_nnfx-coral-trendlord-woodies-harvester` (untracked `.mq5`, `.ex5`,
and `SPEC.md`) and `QM5_30001_bollinger-bands-grid-waka-waka` (untracked
`.mq5`). Those candidates were treated as in-flight collision risks.

## Binding stop condition

Five two-second whole-host CPU samples ending at `2026-08-20T05:50:16Z` were
`100.00%`, `100.00%`, `99.81%`, `99.27%`, and `99.28%`. Average CPU was
`99.67%` and maximum CPU was `100.00%`, above the explicit `97%` ceiling.

A path-anchored process scan found eight active factory terminals: T1, T2, T3,
T4, T5, T6, T8, and T10. `T_Live` was excluded by the executable-path match and
was neither inspected beyond exclusion nor controlled.

Per the mission stop condition, no farm claim, Card, EA, registry row, resolver
output, compile, build check, tester run, smoke, Q02 enqueue, dispatch tick,
terminal reservation, requeue, or priority mutation was performed. No
portfolio gate, T_Live manifest, T_Live file, or AutoTrading state was touched.

Machine-readable evidence is in
`artifacts/diversity_backlog_hard_cpu_stop_20260820T055016Z_board_advisor.json`.
