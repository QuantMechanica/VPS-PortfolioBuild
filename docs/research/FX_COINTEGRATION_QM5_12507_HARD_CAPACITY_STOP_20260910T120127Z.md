# FX cointegration QM5_12507 hard-capacity stop

Recorded: 2026-09-10T12:01:27.233Z (14:01 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `67d7a02f33bc877dd3404482a41119cd92c06933`

## Result

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the frozen scan: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The two preferred anchors have no current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then a
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has a later Q02 `PASS`, then a
  terminal Q04 `FAIL`.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker to repair.

## Existing-pair fallback

The non-duplicate fallback remains the approved and built EURUSD/GBPUSD H1
basket `QM5_12507_pair-coint-z`. Its sole open logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt
zero, has no verdict, and already carries `priority_track=true`. No second
enqueue or redundant priority mutation was made.

Its logical setfile remains the governed basket target and seals
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## PACER build guard

No `.mq5` was generated or edited and no compile enqueue was contemplated. The
existing fallback source was audited read-only with the binding command:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

## Binding hard stop

Five whole-host CPU samples were `97.756%`, `94.727%`, `92.579%`, `96.680%`,
and `87.013%` (average `93.751%`, maximum `97.756%`). The explicit `97%` hard
CPU ceiling fired on the maximum sample.

The governed database simultaneously held four active factory claims on T1,
T7, T8, and T10 while `D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`.
Free physical memory was `46.49 GiB`, below the `58 GiB` admission requirement
for this four-symbol heavy/unknown multisymbol basket.

Per the mission stop condition, no dispatch tick, tester launch, terminal
reservation, Q02 enqueue/requeue, priority mutation, source change, or compile
followed. The existing priority Q02 row remains available to the resident
worker after the CPU, serialized-lane, and RAM gates recover.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_hard_capacity_stop_20260910T120127Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.
