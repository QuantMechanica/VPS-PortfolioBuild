# FX cointegration QM5_12507 Q02 hard-CPU stop

Recorded: 2026-09-10T01:31:50.839Z

Branch: `agents/board-advisor`

## Result

No new pair was carded or built. The durable sign-aware reconciliation at
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships in the frozen scan, with zero uncovered.
Creating another scan-derived Card or EA would duplicate governed work.

The preferred anchors do not have a Q02 setup blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, and a
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS` and a terminal
  Q04 `FAIL`.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` defect to repair.

## Existing-pair fallback

The concrete non-duplicate fallback is the approved and built EURUSD/GBPUSD H1
basket `QM5_12507_pair-coint-z`. Its logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains `pending`, unclaimed, attempt
zero, and `priority_track=true`. This is already the sole open Q02 row for the
logical basket, so no duplicate enqueue or redundant priority rewrite was made.

The package has a compiled `.ex5`, a basket manifest, and a logical backtest
setfile. The setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

No MQ5 was generated or edited and no compile work was contemplated. The PACER
source audit was nevertheless run read-only against the existing source:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

## Binding capacity stop

Five whole-host CPU samples were `96.584076`, `98.550951`, `90.723541`,
`95.508255`, and `97.363542` percent. Their average was `95.746073%` and the
maximum was `98.550951%`, crossing the binding `97%` backtest CPU ceiling.
Available physical memory was 45.119 GiB.

At the same observation point, five governed work items were active while
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`. The current claims were
on T4, T6, T8, T9, and T10. The explicit CPU stop condition therefore bound
before any enqueue, requeue, priority mutation, dispatch tick, terminal
reservation, or tester launch.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260910T013150Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were left untouched and excluded
  from this commit.
