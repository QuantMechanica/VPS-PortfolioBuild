# QM5_12772 Q05 Current-Bridge Requeue

Date: 2026-06-30
Branch: `agents/board-advisor`

## Scope

The forex expansion mission first checked the proven FX cointegration baskets:

- `QM5_12532` is not Q02-blocked; local evidence shows Q02 `PASS`, Q04
  `PASS`, and later Q05 handling.
- `QM5_12533` is not Q02-blocked; local evidence shows Q02 `PASS` and later
  Q04 handling.

No unbuilt allocated `edgelab-*-cointegration` pair remains in the local book
through `QM5_12803`; all current card stubs have matching EA directories.
This pass therefore advanced an existing FX cointegration sleeve without
creating a duplicate basket.

Target: `QM5_12772_edgelab-gbpjpy-audjpy-cointegration`
(`QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1`).

## Pre-Action State

`farmctl work-items --ea QM5_12772` showed:

| Phase | Work item | Status | Verdict |
|---|---|---|---|
| Q02 | `0ef494c0-7669-4c98-9e5c-326ff70df987` | done | PASS |
| Q04 | `1b418d74-da86-4fb2-aa41-74ebca065f05` | done | PASS_SOFT |
| Q05 | `dd43c7e2-7351-41e1-a4a4-f667d0789249` | done | INFRA_FAIL |

The prior Q05 aggregate failed as infra, not strategy:
`invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,RUN_STATUS_INVALID`.

## Queue Action

Requeued the existing Q05 row in place:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12772 --phase Q05
```

Result:

- requeued: `dd43c7e2-7351-41e1-a4a4-f667d0789249`
- created rows: `0`
- skipped rows: `0`
- current status: Q05 `pending`

No manual MT5 run was launched. The paced worker fleet owns execution.

## Bridge Verification

The pending Q05 row now resolves to the current Q-runner command bridge:

```text
python.exe framework/scripts/q05_stress_medium.py
  --ea QM5_12772
  --report-root D:/QM/reports/work_items/dd43c7e2-7351-41e1-a4a4-f667d0789249
  --symbol GBPJPY.DWX
  --logical-symbol QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1
  --baseline-setfile framework/EAs/QM5_12772_edgelab-gbpjpy-audjpy-cointegration/sets/QM5_12772_edgelab-gbpjpy-audjpy-cointegration_QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set
  --terminal T3
```

This uses `--report-root` rather than stale `--out-prefix`, drops the generic
`--period`, runs on the host leg `GBPJPY.DWX`, and records evidence under the
logical basket symbol.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -k "q05_runner_cmd_receives_latest_full_year_cap or q05_accepts_q04_soft_pass_verdicts or enqueue_q05_checks_basket_manifest_symbols" tools/strategy_farm/tests/test_q04_latest_full_year_payload.py -q`
  - Result: `3 passed, 9 deselected, 2 subtests passed`.
- `python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12772`
  - Result: Q02 `PASS`, Q04 `PASS_SOFT`, Q05 `pending`; no duplicate pending/active Q05 row.

## Guardrails

- No `T_Live` manifest touched.
- AutoTrading not toggled.
- No portfolio admission, KPI, Q08 contribution, or deploy manifest artifact touched.
- Q05 remains a RISK_FIXED backtest-setfile queue item.
