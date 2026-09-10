# FX cointegration QM5_12507 hard CPU stop

Recorded: 2026-09-10T10:06:53Z (12:06 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `11dcb9186c`

## Result

No new pair was carded or built. The durable sign-aware reconciliation in
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
basket `QM5_12507_pair-coint-z`. Its unique logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
and already `priority_track=true`. The guarded priority dry-run returned
`already_priority_track`; no second enqueue and no redundant priority write
was made.

The package validated as `BASKET_OK`. Its logical setfile seals
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## PACER build guard

No `.mq5` was generated or edited, and no compile enqueue was contemplated.
The existing source was nevertheless audited read-only with the binding
command:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

## Binding hard stop

At the observation point, five governed `OPT_CENSUS` testers were active on
T10, T2, T3, T6, and T9 while
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`. The paced launch
capacity was already occupied five times over.

Five whole-host CPU samples were 84.572172%, 85.262838%, 96.722748%,
96.097472%, and 100.0% (average 92.531046%, maximum 100.0%). The explicit 97%
hard CPU ceiling therefore fired on the maximum sample. Available physical
memory was 37.963 GiB. The basket's `heavy_or_unknown_multisymbol` class
requires 58 GiB free (44 GiB reservation plus a 14 GiB post-reservation
floor), so the independent RAM admission gate also bound.

Per the mission stop condition, no dispatch tick, tester launch, terminal
reservation, Q02 enqueue/requeue, priority mutation, source change, or compile
followed. The authenticated Q02 row remains owned by normal worker claim order
after capacity recovers.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260910T100653Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were left untouched and are not
  part of this handoff.
