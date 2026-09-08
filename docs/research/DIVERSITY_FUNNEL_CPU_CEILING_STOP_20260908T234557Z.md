# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-08T23:45:57Z (2026-09-09 01:45:57 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `9ec49a6c8907398a5852a6211a6a0d6387315398`

## Outcome

The paced diversity-first mission stopped at its explicit backtest CPU gate
before backlog ranking, EA selection, farm claiming, source generation,
compilation, or Q02 enqueue. No Strategy Card or EA identity was reserved, and
no task or work-item row was advanced, so this wake cannot collide with another
paced agent.

## Binding capacity evidence

Five one-second whole-host `Processor(_Total)\% Processor Time` samples were:

| Sample | CPU |
|---:|---:|
| 1 | 98.484955% |
| 2 | 97.408382% |
| 3 | 95.418519% |
| 4 | 92.676425% |
| 5 | 93.558775% |

Average CPU was `95.509411%`; maximum CPU was `98.484955%`. The maximum
breached the governed requirement that both average and maximum remain strictly
below the `97%` backtest CPU ceiling.

The path-aware `farmctl.py mt5-slots` snapshot at
`2026-09-08T23:45:57Z` reported seven active governed tester terminals:
`T1`, `T3`, `T5`, `T6`, `T7`, `T8`, and `T10`. Read-only farm DB
reconciliation showed seven active work items: four Q04 rows and three
OPT_CENSUS rows. The separately observed `T_Live` and FTMO processes were not
counted as factory capacity and were not touched.

At the same observation point the farm reported 73 pending and six active
`build_ea` tasks. Because the CPU gate takes precedence, those rows were not
ranked or claimed.

## PACER build guard

No `.mq5` source was generated or edited, so the post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile work was enqueued. A later wake must run the audit after writing a
generated source and must refuse compile admission on a nonzero exit or any
`EA_FRAMEWORK_INPUT_PINNED` finding.

## Safety and continuation

No Strategy Card, EA source or binary, setfile, registry, resolver, farm task,
work item, claim, terminal reservation, pipeline verdict, portfolio gate,
`T_Live` manifest, live terminal, or AutoTrading state was changed. Pre-existing
uncommitted changes to `QM5_41240_wti-samecal-ramsaye5` and the untracked
stranded-infra triage receipt were left untouched.

On a later paced wake, take a fresh five-sample whole-host CPU window. Proceed
to diversity-backlog ranking and an atomic distinct-EA claim only when both the
average and maximum are strictly below `97%`.
