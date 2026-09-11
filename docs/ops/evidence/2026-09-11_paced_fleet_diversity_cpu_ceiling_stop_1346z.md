# Paced-fleet diversity CPU-ceiling stop — 2026-09-11 13:46Z

## Outcome

The paced-fleet mission stopped at the binding backtest CPU admission gate
before backlog selection, farm claim, source generation, compile, smoke, or Q02
enqueue. A fresh five-sample whole-host window was `100%, 100%, 99%, 99%,
100%`: average `99.6%`, maximum `100.0%`. The admission rule requires both
values to be strictly below `97.0%`.

No Strategy Card, EA source, EX5, setfile, registry, resolver, farm task, work
item, queue priority, pipeline verdict, portfolio gate, `T_Live` manifest,
deployment manifest, or AutoTrading state was changed. Because no generated
MQ5 was written, the PACER framework-input pin audit boundary was not entered.

Branch: `agents/board-advisor`

Observation HEAD: `7ca687d74eb687a7a631b9c3d216aa42f06fd7fd`

Machine-readable companion:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260911T134639Z_board_advisor.json`.

## Capacity evidence

The sample completed at `2026-09-11T13:46:39.7736741Z`. The process snapshot
contained five `terminal64` and three `metatester64` processes.

The independent farm-DB census immediately after sampling found five governed
tester rows active:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T5 | OPT_CENSUS | QM5_41398 | USDJPY.DWX | `94f58367-7971-58ae-abbe-6cbd56f20d47` |
| T3 | OPT_CENSUS | QM5_41405 | USDJPY.DWX | `26e17d6b-970e-5e1d-a748-a0832f9b0d86` |
| T8 | Q02 | QM5_1637 | XAUUSD.DWX | `729b2361-5c15-4471-903d-211e8879a536` |
| T7 | OPT_CENSUS | QM5_41322 | XAUUSD.DWX | `07c50437-4765-5476-b5e3-607a5a203101` |
| T10 | Q02 | QM5_9235 | XAUUSD.DWX | `4f040db2-31b8-4b2b-ab08-c402c8704580` |

The active-row count was below seven, but CPU remained the binding ceiling.

## Continuation condition

A later paced wake must take a new five-sample CPU window and re-read the farm
DB before claiming work. Continue only when both the CPU average and maximum
are strictly below `97%` and the intended EA has no competing claim. If an MQ5
is generated or changed, run
`audit_framework_input_pins.py --check-source <absolute-mq5-path>` after the
write and before any compile enqueue; a nonzero exit or
`EA_FRAMEWORK_INPUT_PINNED` finding refuses the build.
