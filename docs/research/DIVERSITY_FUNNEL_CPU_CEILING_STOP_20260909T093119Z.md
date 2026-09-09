# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-09T09:31:19.2589364Z (11:31 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `4e5a45605d14a9ab9c0ddeb9f121de4cde5eaf5b`

## Outcome

The paced diversity-first mission stopped at its binding capacity gate before
backlog ranking, Strategy Card selection, or a farm claim. A fresh five-sample
whole-host CPU window measured `100%`, `100%`, `100%`, `100%`, and `100%`.
The average and maximum were both `100%`. Admission requires both values to
remain strictly below `97%`, so the CPU predicate refuses new work.

The independent read-only farm snapshot found ten active governed tester rows
across T1-T10, above the separate exclusive seven-row pacer admission limit.
The CPU and active-row predicates therefore independently require this wake to
stop rather than add compile, smoke, or Q02 pressure.

## Active governed rows

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | Q08 | QM5_12925 | USDJPY.DWX | `68ef5618-7fba-47d7-a6ce-509429abbdee` |
| T2 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `e3ca79c1-5fe7-55e5-8ea4-bcd73b7e1fa5` |
| T3 | OPT_CENSUS | QM5_41161 | GBPUSD.DWX | `9be4895f-e684-50f2-a838-1a141618fda5` |
| T4 | Q06 | QM5_41165 | XTIUSD.DWX | `55e2a16b-cf1f-4ab2-9473-f0cf8a32d4d1` |
| T5 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `c68ab5a0-8573-54f2-a710-2cb5438141e0` |
| T6 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `870b70c5-c4c0-5fb8-b8bb-ee8500e77888` |
| T7 | Q02 | QM5_41394 | EURUSD.DWX | `58b36f74-a831-4119-943b-8a9924b20179` |
| T8 | Q04 | QM5_41176 | XTIUSD.DWX | `d3ec7978-b4e2-4867-ae8c-dbfb0af4887c` |
| T9 | Q02 | QM5_41336 | XTIUSD.DWX | `2bc498cd-a005-454f-9439-b13eb0cf7f23` |
| T10 | OPT_CENSUS | QM5_41322 | XAUUSD.DWX | `0f9ce174-9845-5c7d-b6b3-acada1798710` |

The canonical farm database was opened read-only through `farmctl work-items`.
No row was claimed, created, requeued, reprioritized, or advanced.

## Non-duplicate delta

The preceding diversity stop at `2026-09-09T08:30:04Z` observed nine active
rows and a `95.6%` average CPU window. This fresh observation sees ten active
rows, a different governed roster, and sustained `100%` CPU across every
sample. It therefore records changed fleet and capacity state rather than
repeating the prior receipt.

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
`artifacts/diversity_funnel_cpu_ceiling_stop_20260909T093119Z_board_advisor.json`.

## Continuation

A later paced wake must take a fresh whole-host CPU window and read-only
active-row snapshot. It may rank and atomically claim one distinct
highest-diversity eligible EA only when both CPU measures are strictly below
`97%` and fewer than seven governed tester rows are active. After writing any
generated MQ5, the binding source-pin audit must pass before any compile
enqueue; a nonzero exit or any `EA_FRAMEWORK_INPUT_PINNED` finding refuses the
build.
