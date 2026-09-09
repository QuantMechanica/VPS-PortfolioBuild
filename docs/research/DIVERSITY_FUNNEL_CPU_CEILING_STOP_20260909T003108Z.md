# Diversity funnel CPU and active-tester ceiling stop

Recorded: 2026-09-09T00:31:08.6129420Z (2026-09-09 02:31 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b3b6a6c5179da94b4a0363633a07451172e04b82`

## Outcome

The paced diversity-first mission stopped at its binding capacity gate before
backlog ranking or a farm claim. Fresh whole-host CPU samples averaged `98.4%`
and peaked at `100.0%`. Admission requires both values to remain strictly below
`97.0%`, so the CPU ceiling refused the mission. A subsequent read-only farm DB
snapshot showed nine active governed tester rows, also above the exclusive
seven-row admission limit. `D:` had `82.332 GiB` free and was not binding.

This early refusal avoids colliding with another paced agent or creating a
stranded build that cannot complete its mandatory smoke handoff. No approved
card, diverse Q02-Q03 recovery, or new structural edge was selected after the
capacity result.

## Binding capacity evidence

The five approximately one-second samples from
`Win32_Processor.LoadPercentage` were `97.0%`, `97.0%`, `100.0%`, `99.0%`, and
`99.0%`.

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | Q04 | QM5_1443 | USDCHF.DWX | `c5f4fe32-d591-4204-8657-2cc4a10704a5` |
| T2 | Q04 | QM5_9574 | EURUSD.DWX | `8a25ff0f-fc5e-40f5-afb0-7c09bdb51d96` |
| T4 | Q04 | QM5_1066 | USDJPY.DWX | `6a5c0cc9-631c-45ef-b2b8-53d9d93b1527` |
| T5 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `5fc913b6-02ad-52a7-afa1-f59ca0e3e6d0` |
| T6 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `495c42c0-c27e-5377-ade9-86aec76fe0f5` |
| T7 | Q04 | QM5_1386 | USDCHF.DWX | `3425066d-731f-4e81-b032-0eda77b78f1c` |
| T8 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `b44a607f-8fa0-5a90-9fd9-9ee4e9de3cb0` |
| T9 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `052363d0-e95d-5f38-a3fe-11c5564f71a2` |
| T10 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `97d891c1-85f4-58ce-991f-8e33b5a48a8f` |

Machine-readable companion:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260909T003108Z.json`.

## PACER guard and mutation boundary

No generated `.mq5` was written, so the mandatory
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command or enqueue, smoke test, backtest, Q02 enqueue, dispatch tick,
terminal control, or worker control was started.

No Strategy Card, EA identity, magic row, resolver, EA source, EX5, SPEC,
setfile, farm task, work item, claim, priority, hold, pipeline verdict,
portfolio gate, `T_Live` state, AutoTrading state, deploy manifest, or live
manifest was changed. Existing unrelated shared-worktree changes were
preserved and excluded from this receipt.

## Continuation

A later paced wake must repeat the fresh five-sample CPU window and read-only
active-row census. It may rank and claim exactly one distinct high-diversity EA
only when both CPU average and maximum are strictly below `97%` and fewer than
seven governed tester rows are active. After any MQ5 is generated, the binding
source-pin audit must pass before any compile enqueue; a nonzero exit or any
`EA_FRAMEWORK_INPUT_PINNED` finding refuses the build.
