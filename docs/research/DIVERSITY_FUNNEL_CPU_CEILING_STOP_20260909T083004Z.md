# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-09T08:30:04.7313217Z (10:30 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `58ad7cbd20db60c1196d8ddaabbaf2b2830a3da7`

## Outcome

The paced diversity-first mission stopped at its binding capacity gate before
backlog ranking, Strategy Card selection, or a farm claim. A fresh five-sample
whole-host CPU window measured `88%`, `94%`, `96%`, `100%`, and `100%`.
The average was `95.6%` and the maximum was `100%`. Admission requires both
values to remain strictly below `97%`, so the maximum refuses new work.

The independent read-only farm snapshot found nine active governed tester rows
across T1-T10, above the separate exclusive seven-row pacer admission limit.
The CPU and active-row predicates therefore independently require this wake to
stop rather than add compile, smoke, or Q02 pressure.

## Active governed rows

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | Q04 | QM5_9121 | GBPUSD.DWX | `4358a6af-eeae-45c8-b322-1e46b2eb5b5f` |
| T2 | Q07 | QM5_12925 | USDJPY.DWX | `8847f41b-08dd-4790-b5b8-470eb6be49e5` |
| T3 | Q04 | QM5_10513 | USDJPY.DWX | `33ce2be8-681b-43c4-84a0-a5be676f42b6` |
| T4 | Q04 | QM5_1017 | EURUSD.DWX | `3dea2327-8887-4ac6-9196-5ff2c5aa3454` |
| T5 | OPT_CENSUS | QM5_41161 | GBPUSD.DWX | `b87b3ad4-2abc-5580-840f-e8f074fdb2ed` |
| T7 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `4ec6bb41-add3-5965-ac10-2af96140dc2e` |
| T8 | Q04 | QM5_10562 | GBPUSD.DWX | `76b82dba-521b-4d4f-bd6e-4b8649f17c72` |
| T9 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `6d90f401-737d-5f96-ae7a-919410e0fe1b` |
| T10 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `f3b90d7d-85d4-5830-a4dd-35bdc7fe3a24` |

The canonical farm database was opened read-only. No row was claimed, created,
requeued, reprioritized, or advanced.

## PACER guard and safety boundary

No generated `.mq5` was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command or enqueue, smoke test, backtest, Q02 enqueue, dispatch tick,
terminal control, or process control was run.

No Strategy Card, EA source, EX5, SPEC, setfile, identity registry, magic
registry, resolver, farm task, work item, pipeline verdict, portfolio gate,
`T_Live` manifest, deploy manifest, live terminal, or AutoTrading state was
changed. Existing unrelated shared-worktree changes were preserved and
excluded from this receipt.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260909T083004Z_board_advisor.json`.

## Continuation

A later paced wake should take a fresh whole-host CPU window and read-only
active-row snapshot. It may rank and atomically claim one distinct
highest-diversity eligible EA only when both CPU measures are strictly below
`97%` and fewer than seven governed tester rows are active. After writing any
generated MQ5, the binding source-pin audit must pass before any compile
enqueue; a nonzero exit or any `EA_FRAMEWORK_INPUT_PINNED` finding refuses the
build.
