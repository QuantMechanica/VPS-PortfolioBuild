# Diversity funnel hard CPU stop

Recorded: 2026-09-08T19:02:19Z (21:02 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `7dabf25ea72106f1d6c45d991ac136792befddf0`

## Outcome

The diversity-first paced-fleet mission stopped at its explicit capacity gate
before backlog ranking, Strategy Card selection, or a farm claim. A five-sample
whole-host CPU window averaged `98.396721%` and peaked at `99.815616%`, both
above the strict `<97%` admission ceiling. The same read-only farm snapshot
showed all ten governed tester terminals actively claimed, above the separate
seven-tester pacer threshold.

No candidate identity was claimed, so this wake cannot collide with another
paced agent. In particular, it did not duplicate the already source-hash-bound
`QM5_34008` compile path recorded by the preceding diversity audit.

## Binding capacity evidence

CPU samples were `98.535996%`, `98.349937%`, `96.524679%`, `98.757375%`, and
`99.815616%`.

| Terminal | Phase | EA | Symbol | Work item |
|---|---|---|---|---|
| T1 | Q07 | QM5_41173 | XTIUSD.DWX | `80a16837-682b-4713-a0f5-0f6795ab1728` |
| T2 | OPT_CENSUS | QM5_41301 | XAUUSD.DWX | `41012ab9-f1a1-563e-be01-54626eca95ae` |
| T3 | OPT_CENSUS | QM5_41324 | USDJPY.DWX | `31f1d1cb-c6af-5821-9e7d-65229d3b65b7` |
| T4 | Q06 | QM5_41182 | XTIUSD.DWX | `c8628c37-a775-4bbe-9988-0e0ea1b2dc8a` |
| T5 | OPT_CENSUS | QM5_41345 | XAUUSD.DWX | `8b87231b-3684-504d-ad46-47428cc226e6` |
| T6 | Q04 | QM5_10122 | GBPJPY.DWX | `c5ec0aa3-1df6-42f2-aa42-ca869b070b89` |
| T7 | OPT_CENSUS | QM5_41302 | XAUUSD.DWX | `24e9a2fd-49a1-599f-b30d-5e648ec12687` |
| T8 | Q07 | QM5_41158 | XTIUSD.DWX | `2c3757b4-1bbc-46c6-b19b-f1c5423b4127` |
| T9 | Q04 | QM5_10144 | GBPJPY.DWX | `c71d75b1-8e88-47b6-bb2d-660a0097c5d8` |
| T10 | OPT_CENSUS | QM5_41163 | USDCAD.DWX | `ed7b8c46-8cfb-551e-b70d-686febc07ac7` |

Machine-readable evidence is in
`artifacts/diversity_funnel_hard_cpu_stop_20260908T190219Z_board_advisor.json`.

## PACER guard and safety boundary

No generated `.mq5` was written or edited, so the post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command, smoke, backtest, Q02 enqueue, dispatch tick, terminal control,
or process control was run.

No Strategy Card, EA source, EX5, SPEC, setfile, basket manifest, registry,
resolver, farm task, work item, claim, priority, hold, pipeline verdict,
portfolio gate, `T_Live` manifest, deploy manifest, live terminal, or
AutoTrading state was changed. Existing unrelated shared-worktree changes were
preserved and excluded from this receipt.

## Continuation

A later paced wake should take a fresh five-sample CPU window and active-tester
snapshot. It may rank and atomically claim exactly one distinct diversity-first
candidate only when both admission predicates clear.
