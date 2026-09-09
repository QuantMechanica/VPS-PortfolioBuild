# Diversity funnel hard CPU stop

Recorded: 2026-09-09T15:30:11.8201613Z (2026-09-09 17:30 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `39fd46a2e277558392d308756e74b219649de2aa`

## Outcome

The diversity-first paced mission stopped at the binding whole-host CPU gate
before backlog ranking, farm claiming, source generation, compile, or Q02
enqueue. The five fresh samples averaged `84.8%`, but peaked at `100.0%`.
Admission requires both the average and maximum to be strictly below `97.0%`;
the maximum therefore refused this wake.

No Strategy Card or EA identity was selected or reserved. This preserves the
mission's diversity and non-duplication order instead of making a speculative
selection while the capacity stop binds.

## Capacity evidence

The five approximately two-second samples from
`Win32_PerfFormattedData_PerfOS_Processor` with `Name='_Total'` were:

| Sample | CPU |
|---:|---:|
| 1 | 54.0% |
| 2 | 100.0% |
| 3 | 98.0% |
| 4 | 100.0% |
| 5 | 72.0% |

At the sampling snapshot, four `terminal64` processes were visible and
available physical memory was `43.953 GiB`. The immediately following
path-aware `farmctl.py mt5-slots` snapshot identified one governed factory
terminal, `T2`, running `OPT_CENSUS` work item
`263f5d23-675f-5f1a-a2b1-323930176259` for `QM5_41321 / NDX.DWX`.
`T_Live` and the unrelated FTMO terminal were observed only to exclude them;
neither was controlled. A subsequent supported active-work query returned zero
rows after that run completed. Drive `D:` had `80.270 GiB` free and was not
binding.

Machine-readable companion:
`artifacts/diversity_funnel_hard_cpu_stop_20260909T153011Z.json`.

## PACER guard and mutation boundary

No generated `.mq5` was written, so the mandatory
`audit_framework_input_pins.py --check-source` boundary was not entered. There
was no `EA_FRAMEWORK_INPUT_PINNED` finding because there was no generated
source to audit, and no compile or compile-enqueue command followed.

No Strategy Card, EA source or binary, setfile, registry, resolver, farm task,
work item, claim, queue priority, hold, verdict, portfolio gate, `T_Live`
manifest, live terminal, deploy artifact, or AutoTrading state was changed.
Pre-existing shared-worktree changes were preserved and excluded from this
receipt.

## Continuation

A later paced wake must repeat the fresh five-sample whole-host CPU window. It
may rank and claim exactly one distinct high-diversity candidate only when both
average and maximum CPU are strictly below `97.0%`. After any MQ5 is generated,
the binding source-pin audit must pass before any compile action; a nonzero exit
or any `EA_FRAMEWORK_INPUT_PINNED` finding refuses the build and Q02 enqueue.
