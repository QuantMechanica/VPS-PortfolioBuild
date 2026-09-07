# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-07T15:16:30Z (17:16 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `6ecbdea87e247a7320203dbe6b36a295804a4a7c`

## Outcome

The diversity-first paced-fleet mission stopped at its explicit capacity gate
before backlog ranking, Strategy Card selection, or a farm claim. The first
whole-host CPU window reached the `97%` ceiling, and the read-only farm snapshot
concurrently showed seven active governed tester rows, which is the pacer
saturation threshold. No EA identity or task was claimed, so this wake cannot
collide with another paced agent.

## Binding capacity evidence

The initial one-second whole-host CPU samples were `100.00%`, `99.72%`, and
`97.10%`; their average was `98.94%` and maximum was `100.00%`. Both exceed the
requirement that average and maximum remain strictly below `97%`.

A subsequent five-sample window measured `90.733889%`, `94.072990%`,
`85.359454%`, `90.243638%`, and `82.727008%` (average `88.627396%`, maximum
`94.072990%`). That later dip does not reverse the already-triggered stop, and
the independent governed-tester ceiling remained binding at seven active rows:

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T2 | Q10_NEWS | QM5_11167 | XAUUSD.DWX | `f625d9aa-da34-44bb-aa9f-0eda284f3f32` |
| T3 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `74bce3a9-1246-50f7-83e9-228ab962bc11` |
| T8 | OPT_CENSUS | QM5_41347 | XAUUSD.DWX | `0843ecbb-4123-5682-a8d2-3b9411bab8a4` |
| T6 | Q06 | QM5_41115 | XTIUSD.DWX | `71938037-dd34-4b05-9944-f51c82d3be3f` |
| T7 | Q03 | QM5_41122 | XTIUSD.DWX | `3604ca86-543b-469c-8242-b16e52be94c5` |
| T9 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `149ec025-75cc-5236-945c-a6e157bdd035` |
| T10 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `dc8a79f7-99b7-5fcd-b83f-4a3c65a1f351` |

The same read-only database snapshot contained 73 pending and six active
`build_ea` tasks. Capacity takes precedence over candidate ranking and claiming.
The `T_Live` and unrelated FTMO terminals observed by the path-aware process
inventory were not counted as factory capacity and were not touched.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260907T1515Z.json`.

## PACER guard and safety boundary

No generated `.mq5` was written or edited, so the post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command, smoke, backtest, Q02 enqueue, dispatch tick, terminal control,
or process control was run.

No Strategy Card, EA source, EX5, SPEC, setfile, basket manifest, identity or
magic registry, resolver, farm task, work item, claim, priority, hold, pipeline
verdict, portfolio gate, `T_Live` manifest, deploy manifest, live terminal, or
AutoTrading state was changed. Existing unrelated shared-worktree changes were
preserved and excluded from this receipt.

## Continuation

A later paced wake should take a fresh whole-host CPU window and a fresh
read-only active-tester count before ranking the diversity backlog. It should
claim exactly one distinct eligible EA only after both admission checks clear.
