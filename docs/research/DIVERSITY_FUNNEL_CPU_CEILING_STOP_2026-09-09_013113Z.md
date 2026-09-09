# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-09T01:31:13Z (03:31 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `a0385258d281b48afe9edf5d8ef6960e794cbdc9`

## Outcome

The diversity-first paced-fleet mission stopped at its explicit capacity gate
before backlog ranking, Strategy Card selection, or a farm claim. A fresh
five-sample whole-host CPU window measured `97.684621%`, `98.788530%`,
`97.909401%`, `91.803985%`, and `89.746985%`. The average was `95.186704%`
and the maximum was `98.788530%`. Admission requires both values to remain
strictly below `97%`, so the maximum alone refuses new work.

The independent read-only farm snapshot found ten active governed tester rows
across T1-T10, above the separate seven-row pacer saturation threshold. The
CPU and DB predicates therefore both require this wake to stop rather than add
compile, smoke, or Q02 pressure.

## Active governed rows

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `8ec76542-bd61-5d4c-abbc-14399d44404d` |
| T2 | Q04 | QM5_1614 | EURUSD.DWX | `0898b17f-8492-4138-9c6b-bf073b2298c9` |
| T3 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `9818ef6c-fcb9-513a-a5df-c7c9eb160c36` |
| T4 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `c8033eb7-902b-5a90-8c19-413818b041ea` |
| T5 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `c45b4d7b-c4bc-5d3c-86e0-19ebb418b40f` |
| T6 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `fa4f467e-b9bd-5933-9bc2-57d15d40d38e` |
| T7 | Q04 | QM5_10297 | AUDNZD.DWX | `067f99a2-5640-4e78-aaa7-26b0a14bb605` |
| T8 | Q04 | QM5_10207 | EURUSD.DWX | `e4ad475a-ac6c-48ce-aa8d-25778bc96b51` |
| T9 | Q04 | QM5_10232 | EURJPY.DWX | `f4935154-b15e-4656-a01d-5b391ebc2d0d` |
| T10 | Q04 | QM5_1235 | EURUSD.DWX | `2a405a5f-47b2-42aa-9db2-ec83e15decbe` |

The canonical farm database was opened read-only. No row was claimed, created,
requeued, reprioritized, or advanced.

## PACER guard and safety boundary

No generated `.mq5` was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command, smoke, backtest, Q02 enqueue, dispatch tick, terminal control,
or process control was run.

No Strategy Card, EA source, EX5, SPEC, setfile, identity registry, magic
registry, resolver, farm task, work item, pipeline verdict, portfolio gate,
`T_Live` manifest, deploy manifest, live terminal, or AutoTrading state was
changed. Existing unrelated shared-worktree changes were preserved and
excluded from this receipt.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260909T013113Z.json`.

## Continuation

A later paced wake should take a fresh whole-host CPU window and read-only
active-tester snapshot. It may rank and atomically claim one distinct
diversity candidate only when both admission predicates clear.
