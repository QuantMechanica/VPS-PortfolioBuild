# FX cointegration fallback hard CPU stop

Recorded: 2026-09-13T02:46:04.5843137Z (2026-09-13 04:46 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `fd03d8d7992f8f332bdf65c0c356469725b011d7`

## Outcome

The frozen 66-pair FX cointegration discovery remains fully represented by
existing builds. The only two pairs that met the published strict threshold
are already beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 `PASS`, Q04 `PASS`, Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 `PASS`, Q04 `FAIL`.

Creating another scan-derived Strategy Card, EA identity, basket manifest,
compile row, or Q02 row would duplicate governed work.

The selected existing-forex continuation remains
`QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1`. Its authenticated chain has
Q02-Q07 `PASS` and current-contract Q09 `PASS`. The required Q08 regeneration
already exists exactly once as work item
`b68d05cd-e52c-43a5-96aa-5e0306efa60f`: pending, unclaimed, attempt zero, and
verdict-free. A second Q08 row would be duplicate work.

The existing Q02 fallback is also preserved exactly once. Work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt
zero, and verdict-free for
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`. No duplicate Q02 row was appended.

## Binding CPU stop

Five fresh whole-host samples taken two seconds apart were `100%`, `100%`,
`99.902764%`, `100%`, and `99.861382%`. Average CPU was `99.952829%` and
maximum CPU was `100%`, above the binding 97% ceiling.

The concurrent farm snapshot contained six active and 5,273 pending work
items. Free physical memory was 34.01 GiB of 63.12 GiB. After the ceiling
fired, no enqueue, requeue, claim, dispatch tick, tester launch, terminal
reservation, terminal control, compile, or backtest was attempted.

## PACER guard and safety

No generated `.mq5` source was written or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered. No
compile command was enqueued.

- No card, EA source or binary, setfile, basket manifest, registry, magic row,
  farm task, work item, priority, claim, hold, or verdict changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest, terminal, deploy artifact, AutoTrading state, or live
  artifact changed.
- Unrelated shared-worktree changes were preserved and excluded from this
  evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260913T024604Z_board_advisor.json`.
