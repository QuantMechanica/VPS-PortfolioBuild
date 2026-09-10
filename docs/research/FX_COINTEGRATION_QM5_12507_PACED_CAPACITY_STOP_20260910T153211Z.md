# FX cointegration QM5_12507 paced-capacity stop

Recorded: 2026-09-10T15:32:11.136Z (17:32 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b53277e789e103dd29aa41bccaa1fb28395dc8a3`

## Result

The frozen sign-aware 66-pair FX scan remains fully mechanized: 66
relationships are covered and zero are uncovered. No new Strategy Card or EA
identity was created because that would duplicate governed work.

The preferred anchors still have no Q02 setup defect to repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then terminal
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then terminal Q04
  FAIL.

Neither anchor is blocked by Q02 ONINIT or NO_HISTORY.

## Selected existing forex pair

The concrete fallback is `QM5_12507_pair-coint-z`, trading the EURUSD/GBPUSD
cointegration pair on H1. Its logical basket Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains the sole matching open row:
pending, unclaimed, attempt zero, no verdict, and already
`priority_track=true`. Its payload contains the basket manifest, host binding,
four required warmed symbols, and active custom-history admission.

The logical setfile keeps the required backtest risk contract:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No duplicate enqueue or redundant priority mutation was performed.

## Verification

The binding framework-input-pin audit passed:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The target-specific basket regression also passed:

```text
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q -k qm5_12507
1 passed, 46 deselected
```

## Binding capacity stop

Five whole-host CPU samples were `82.619%`, `72.478%`, `70.413%`, `63.685%`,
and `61.922%` (average `70.223%`, maximum `82.619%`). The explicit 97% CPU
ceiling did not fire.

The paced basket lane was nevertheless inadmissible. Free physical memory was
`40.859 GiB`, below the documented `58 GiB` heavy-multisymbol threshold. The
database also held five active factory claims on T6-T10 while
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`.

No dispatch tick, tester launch, terminal reservation, Q02 enqueue/requeue,
priority mutation, source change, compile, or verdict mutation followed. The
existing priority Q02 row remains available for the resident worker once RAM
and serialized launch capacity recover.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_paced_capacity_stop_20260910T153211Z_board_advisor.json`.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.
