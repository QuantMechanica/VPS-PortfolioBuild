# FX cointegration QM5_20195 Q03 priority and CPU stop

Recorded: 2026-09-12T01:48:39Z (03:48 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `9648d20a93768ed9f98a10df365fe1dadabee31c`

## Outcome

The frozen 66-pair FX cointegration frontier remains fully mechanized, and
the two preferred anchors are not blocked at Q02: `QM5_12532` and
`QM5_12533` both have canonical Q02 `PASS` evidence. Creating another card,
EA identity, basket manifest, compile row, or Q02 row for the scan would be
duplicate work.

The selected existing-forex fallback is the rank-12 NZDUSD/EURGBP D1
market-neutral basket `QM5_20195_nzd-eurgbp-coint`. It has an APPROVED card,
canonical Q02 `PASS`, and exactly one existing logical-basket Q03 row:
`59fa650c-22f2-4608-bb98-15180abc2aca`. That row was pending, unclaimed,
attempt-zero, and not priority-tracked. The governed controller marked that
same row `priority_track=true` at `2026-09-12T01:48:04Z`; no enqueue, requeue,
or duplicate row was created.

## PACER guard and artifact bindings

No MQ5 was generated or modified and no compile work was enqueued. The
selected source passed the binding audit:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_20195_nzd-eurgbp-coint/QM5_20195_nzd-eurgbp-coint.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The logical setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The current artifacts are hash-bound in the companion
JSON record, including the EA source, EX5, basket manifest, and logical
backtest setfile.

## Binding CPU stop

Five one-second whole-host CPU samples were `97.851801%`, `95.220169%`,
`89.162484%`, `92.679841%`, and `93.470325%`. The `97%` backtest CPU ceiling
was hit (maximum `97.851801%`; average `93.676924%`). Eight work items were
active and 6,830 were pending, with seven factory terminals running.

Per the mission guard, no dispatch tick, tester launch, terminal reservation,
or further queue mutation followed. The priority-tracked Q03 row remains for
the resident paced worker after capacity recovers.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No deploy manifest, `T_Live`, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_20195_q03_priority_cpu_stop_20260912T014804Z_board_advisor.json`.
