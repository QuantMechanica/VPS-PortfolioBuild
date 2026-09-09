# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-09T14:45:37.8649390Z (2026-09-09 16:45 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `545ece6087ffcd5a6ef2ca775f98f65a80bef074`

## Outcome

The paced diversity-first mission stopped at its explicit backtest CPU gate
before backlog ranking, candidate selection, farm claiming, source generation,
compilation, smoke, or Q02 enqueue. Five fresh whole-host samples averaged
`98.2%` and peaked at `100.0%`. Admission requires both values to remain
strictly below `97.0%`, so the CPU ceiling refused this wake.

This early refusal avoids colliding with another paced agent or adding compile,
smoke, or tester load to a saturated host. No Strategy Card or EA identity was
selected or reserved.

## Binding capacity evidence

The five approximately two-second samples from
`Win32_PerfFormattedData_PerfOS_Processor` with `Name='_Total'` were:

| Sample | CPU |
|---:|---:|
| 1 | 97.0% |
| 2 | 98.0% |
| 3 | 100.0% |
| 4 | 100.0% |
| 5 | 96.0% |

The contemporaneous path-aware `farmctl.py mt5-slots` snapshot reported four
active governed tester terminals: `T1`, `T5`, `T9`, and `T10`. Their work was
three `OPT_CENSUS` rows and one `Q07` row. The separately observed `T_Live` and
FTMO processes were not counted as factory work and were not touched. Drive
`D:` had `80.492 GiB` free and was not binding.

Machine-readable companion:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260909T144537Z.json`.

## PACER guard and mutation boundary

No generated `.mq5` was written, so the mandatory
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command or compile enqueue was issued.

No Strategy Card, EA source or binary, setfile, registry, resolver, farm task,
work item, claim, priority, hold, pipeline verdict, portfolio gate, `T_Live`
manifest, live terminal, deploy artifact, or AutoTrading state was changed.
Existing unrelated staged, unstaged, and untracked worktree changes were
preserved and excluded from this receipt.

## Continuation

A later paced wake must repeat the fresh five-sample CPU window. It may rank and
claim exactly one distinct high-diversity candidate only when both average and
maximum CPU are strictly below `97%`. After any MQ5 is generated, the binding
source-pin audit must pass before any compile enqueue; a nonzero exit or any
`EA_FRAMEWORK_INPUT_PINNED` finding refuses the build.
