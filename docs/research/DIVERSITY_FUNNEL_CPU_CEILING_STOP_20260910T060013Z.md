# Diversity funnel CPU-ceiling stop

Recorded: 2026-09-10T06:00:13.9957785Z (2026-09-10 08:00 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b3f57de5d29832278f1d4353662d94bb3140f1c4`

## Outcome

The paced diversity mission stopped at its binding capacity gate. Five fresh
`Win32_PerfFormattedData_PerfOS_Processor` `_Total` samples were all `100.0%`.
Both the average and maximum were therefore `100.0%`, violating the strict
admission requirement that both statistics remain below `97.0%`.

Three governed `OPT_CENSUS` testers were active at the observation time: T1 on
`QM5_41322/XAUUSD.DWX`, T7 on `QM5_41301/XAUUSD.DWX`, and T8 on
`QM5_41345/XAUUSD.DWX`. The unrelated `T_Live` and FTMO terminals were observed
but excluded from the governed tester count and were not controlled. D: had
121,768,218,624 free bytes (113.405 GiB), so disk capacity was not binding.

## Non-duplicate state

This is a fresh observation after the repository frontier advanced to
`QM5_41413`; the observation head's latest change is
`pipeline: enqueue QM5_41413 logical Q02 canary`. The active tester set also
differs from the latest prior diversity stop receipt. The receipt therefore
captures changed farm and repository state rather than repeating an unchanged
measurement.

## Guarded actions

The CPU ceiling bound before any backlog claim or generated source. No farm
DB mutation, card selection, identity or magic allocation, MQ5 write, compile,
smoke, or Q02 enqueue was performed. Because no MQ5 was generated, the mandatory
`audit_framework_input_pins.py --check-source` boundary was not entered and no
compile action followed.

The portfolio gate, T_Live, AutoTrading, deploy manifests, and the live manifest
were untouched. Pre-existing worktree changes were preserved and are excluded
from this evidence unit.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260910T060013Z_board_advisor.json`.

## Continuation condition

A later paced wake must take a new five-sample whole-host CPU window and may
proceed only when both its average and maximum are strictly below 97%. After any
MQ5 is generated, the binding input-pin audit must pass before compile enqueue.
