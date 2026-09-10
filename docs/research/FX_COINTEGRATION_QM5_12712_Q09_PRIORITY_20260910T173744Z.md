# FX cointegration QM5_12712 Q09 priority handoff

Recorded: 2026-09-10T17:37:44Z (19:37 Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

No duplicate Strategy Card or EA was created. The frozen sign-aware 66-pair
scan remains fully mechanized: 66 relationships are covered and zero are
uncovered. The two preferred anchors also have no Q02 setup defect to repair:

- `QM5_12532` AUDUSD/NZDUSD has Q02 `PASS`, Q04 `PASS`, then terminal Q05
  `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has Q02 `PASS`, then terminal Q04 `FAIL`.

The mission-authorized existing-card fallback advanced
`QM5_12712_edgelab-eurgbp-euraud-cointegration`, the EURGBP/EURAUD D1 basket.
Its unique Q09 successor `844cb4a9-5cd5-4198-a8ae-56e5764f3bea` was pending,
unclaimed, verdict-null, attempt zero, and free of active holds, but did not
carry priority metadata. The governed queue-order operation set
`priority_track=true` at `2026-09-10T17:37:44+00:00`.

The row remains the only open Q09 identity for the exact EA and logical basket.
No duplicate enqueue, dispatch tick, tester launch, terminal reservation, or
verdict mutation was performed.

## Why this pair

The reproducible positive-hedge scan ranks EURGBP/EURAUD fifth overall, after
the terminal 12533/12532 anchors and the already-falsified rank-4 NZDUSD/EURJPY
continuation. Its frozen research measurements are DEV net Sharpe `0.661710`,
OOS net Sharpe `0.619076`, OOS return `+3.541437%`, 25 OOS state changes,
hedge beta `0.312529`, and a 40.191-D1-bar half-life.

The approved runtime Card cites Ernest P. Chan's cointegration method and the
in-house Darwinex `.DWX` scan. Mechanics remain structural and low-frequency:
a fixed-beta D1 log spread, 60-bar rolling z-score, fixed `2.0` entry and `0.5`
exit thresholds, no refit, no ML, and a two-traded-leg basket manifest.

The Q09 row is the existing successor of Q08 work item
`b1bd1d06-dbfb-4d16-9951-3ea89e14d64f`, whose terminal verdict is
`FAIL_SOFT`; no closed economic failure was overwritten or revived.

## PACER guard and verification

No `.mq5` was generated or edited and no compile work was enqueued. The
existing source nevertheless passed the binding framework-input-pin audit:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/QM5_12712_edgelab-eurgbp-euraud-cointegration.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The target-specific basket regression also passed:

```text
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q -k qm5_12712
1 passed, 46 deselected
```

The logical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Capacity stop

Five post-mutation whole-host CPU samples were `95.313%`, `89.583%`,
`91.312%`, `84.985%`, and `93.461%` (average `90.931%`, maximum `95.313%`).
The explicit 97% CPU ceiling did not fire.

Dispatch remained inadmissible: free physical memory was `42.16 GiB`, below
the documented `58 GiB` heavy-multisymbol requirement, and five factory claims
were active while `D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`.
The priority row is left for the resident paced worker after RAM and serialized
launch capacity recover.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12712_q09_priority_20260910T173744Z_board_advisor.json`.
