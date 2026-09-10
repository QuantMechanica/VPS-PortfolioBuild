# FX cointegration QM5_12507 paced-capacity stop

Recorded: 2026-09-10T11:03:09.994Z (13:03 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `818e68fa74`

## Result

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the frozen scan: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The two preferred anchors do not have a Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then a
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then a terminal
  Q04 `FAIL`.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

## Existing-pair fallback

The non-duplicate fallback remains the approved and built EURUSD/GBPUSD H1
basket `QM5_12507_pair-coint-z`. Its sole open logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
has no active hold, and already has `priority_track=true`. No second enqueue or
redundant priority write was made.

The approved card records G0 `APPROVED` and R1-R4 `PASS`. The logical setfile
seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The basket
manifest suite passed all 47 tests, including declaration of every symbol the
EA warms.

## PACER build guard

No `.mq5` was generated or edited and no compile enqueue was contemplated. The
existing source was audited read-only with the binding command:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

## Capacity stop

The explicit 97% CPU ceiling did not bind. Five one-second whole-host samples
were 85.942121%, 82.617214%, 89.752313%, 84.669620%, and 83.310910%
(average 85.258436%, maximum 89.752313%).

The serialized paced lane was nevertheless occupied: three governed factory
testers were active on T2, T5, and T9 while
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`. Available physical
memory was 43.0 GiB, below the 58 GiB admission requirement for this
four-symbol heavy/unknown multisymbol basket. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them from the factory count; neither
was controlled.

No dispatch tick, tester launch, terminal reservation, Q02 enqueue/requeue,
priority mutation, source change, or compile followed. The existing priority
Q02 row remains owned by normal worker claim order after both capacity gates
recover.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_paced_capacity_stop_20260910T110309Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.
