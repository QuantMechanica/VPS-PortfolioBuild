# Diversity funnel CPU-ceiling stop — 2026-09-12 05:02:38Z

Branch: `agents/board-advisor`

## Outcome

The paced-fleet admission check crossed the binding 97% whole-host CPU
ceiling before any farm claim or build mutation. Work stopped without claiming
an EA, generating or editing an `.mq5`, running a compile, launching a tester,
or enqueueing Q02.

## Capacity evidence

Five one-second `Processor(_Total)\% Processor Time` samples were taken with
PowerShell `Get-Counter`:

| Sample | CPU |
|---:|---:|
| 1 | 99.80% |
| 2 | 100.00% |
| 3 | 98.93% |
| 4 | 98.34% |
| 5 | 99.32% |

- Average: **99.28%**
- Maximum: **100.00%**
- Admission ceiling: **97.00%**
- Result: **REFUSE** (both average and maximum must remain below 97%)

## Farm coordination snapshot

The read-only farm snapshot at admission time reported five active and 75
pending `build_ea` tasks. Active identities already included the diverse FX
build `QM5_38006`, GBPUSD sibling `QM5_41197`, and market-neutral XAU/XAG
build `QM5_41185`; therefore no overlapping identity was claimed. Pending FX
cards remained available for a later capacity-admissible wake, including
`QM5_41011_tokyo-london-bank-flow-handover` and
`QM5_32007_london-fix-wm-reuters-currency-drift`.

## PACER guard and safety boundary

No generated source was written, so the mandatory
`audit_framework_input_pins.py --check-source` pre-enqueue condition was not
reached. In particular:

- no `enqueue-compile` command was issued;
- no Q02 work item was created;
- no farm task or EA identity was claimed or advanced;
- no terminal or backtest process was launched;
- no portfolio gate, `T_Live`, deploy manifest, or AutoTrading state was
  touched.

The next paced wake should repeat the five-sample CPU admission check before
ranking and atomically claiming one distinct diversity-first EA.
