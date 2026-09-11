# Diversity funnel hard CPU stop

Recorded: 2026-09-11T05:45:47.0249988Z (2026-09-11 07:45 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `3a4380732ef4f0df7c01febaab5a97ee78d1176e`

## Outcome

The paced strategy-farm mission stopped at its binding capacity gate before
backlog selection, farm claim, Strategy Card or registry mutation, EA build,
compile, smoke, or Q02 enqueue. A fresh five-sample whole-host CPU window
averaged `91.4%` and peaked at `99.0%`. The strict admission rule requires both
values to remain below `97.0%`, so the peak refused the mission.

The independent read-only farm DB census found five active tester rows, which
passed the separate fewer-than-seven condition. `D:` had `74.116 GiB` free and
was recorded for context; CPU was the binding gate.

## Binding capacity evidence

CPU samples from `Win32_Processor.LoadPercentage` were `99.0%`, `99.0%`,
`88.0%`, `85.0%`, and `86.0%`.

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T10 | OPT_CENSUS | QM5_41398 | USDJPY.DWX | `2f1f8a1e-cbc6-5dce-aa6b-da35c041d7f3` |
| T6 | Q04 | QM5_10715 | XAUUSD.DWX | `678387d2-b04b-4804-9698-77f32c88e057` |
| T9 | OPT_CENSUS | QM5_41322 | XAUUSD.DWX | `74b354ef-1226-57e7-8e3c-cb9078ae6fa3` |
| T4 | Q08 | QM5_12552 | EURUSD.DWX | `e5b3b516-4f27-47cd-934d-d2ef62d2ef27` |
| T2 | Q04 | QM5_11622 | EURUSD.DWX | `e8c5b775-7c98-42b2-90d5-020b1b4639f0` |

Machine-readable companion:
`artifacts/diversity_funnel_hard_cpu_stop_20260911T054547Z.json`.

## Guard and safety boundary

No EA was claimed because capacity admission precedes backlog selection. No
generated `.mq5` was written, so the mandatory
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command, compile enqueue, manual backtest, Q02 enqueue, dispatch, or
terminal-control command was issued.

No Strategy Card, EA identity, magic row, resolver, MQ5, EX5, setfile, farm
task, work item, queue priority, pipeline verdict, portfolio gate, `T_Live`
state, AutoTrading state, deploy manifest, or live manifest was changed.
Existing unrelated shared-worktree changes were preserved and excluded from
this receipt.

## Continuation condition

A later paced wake must repeat the fresh five-sample CPU window and governed
active-row census. It may claim one diverse non-duplicate unit only when both
CPU average and maximum are strictly below `97%` and fewer than seven governed
tester rows are active. After any MQ5 is generated, the binding source-pin
audit must pass before any compile enqueue is attempted.
