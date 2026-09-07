# Diversity build backlog hard CPU stop

Recorded: 2026-09-07T11:59:52Z (13:59 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `4e02a361f1da149304abf0407d4c7a26f185f7f9`

## Outcome

The diversity-first paced-fleet mission stopped at its explicit capacity gate
before selecting or claiming a Strategy Card. The authoritative farm snapshot
showed 73 pending and six active `build_ea` tasks, but the capacity rule takes
precedence over backlog ranking and claiming. No EA identity was reserved and no
farm row was claimed or advanced, so this wake cannot collide with another paced
agent.

## Binding capacity evidence

The required five one-second whole-host CPU samples were:

| Sample | CPU |
|---:|---:|
| 1 | 99.616385% |
| 2 | 99.820872% |
| 3 | 99.141310% |
| 4 | 99.317690% |
| 5 | 96.208572% |

Average CPU was `98.820966%` and maximum CPU was `99.820872%`. Both breach
the governed requirement that average and maximum remain strictly below the
`97%` backtest CPU ceiling.

The path-aware farm snapshot simultaneously reported seven active governed
tester terminals: `T1`, `T2`, `T4`, `T5`, `T8`, `T9`, and `T10`. Their active
work comprised one Q02 row, one Q10_NEWS row, and five OPT_CENSUS rows. The
separately observed `T_Live` and unrelated FTMO processes were not counted as
factory capacity and were not touched.

## PACER build guard

No `.mq5` source was generated or edited, so the post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile work was enqueued. A later wake must rerun the audit after writing any
generated EA and must refuse compile admission on a nonzero exit or any
`EA_FRAMEWORK_INPUT_PINNED` finding.

## Safety and continuation

No Strategy Card, EA source or binary, SPEC, setfile, basket manifest, identity
registry, magic registry, resolver, farm task, work item, claim, priority, hold,
terminal reservation, tester process, pipeline verdict, portfolio gate,
`T_Live` manifest, live terminal, or AutoTrading state was changed. Concurrent
unrelated worktree changes were left unstaged and untouched.

On a later paced wake, take a fresh five-sample whole-host CPU window. Proceed
with diversity backlog ranking and an atomic distinct-EA claim only when both
the average and maximum are strictly below `97%`.
