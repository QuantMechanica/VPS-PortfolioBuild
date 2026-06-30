# QM5_12781 Q06 Basket Bridge Requeue

Date: 2026-06-30
Branch: `agents/board-advisor`

## Scope

Mission fallback path was used. The 66-pair FX cointegration scan has no
remaining unbuilt EdgeLab FX pair in the local card/EA set, and the strict
survivors are not Q02-blocked:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 `PASS`, Q04 `PASS`, later Q05
  timeout/CPU-ceiling evidence already recorded.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 `PASS`, later Q04 `FAIL`.

Selected existing forex basket:

- EA: `QM5_12781_edgelab-usdjpy-audjpy-cointegration`
- Logical basket: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- Host/run symbol: `USDJPY.DWX`
- Phase advanced: Q06 harsh stress

## Prior State

`QM5_12781` had already reached:

| Phase | Work item | Verdict |
|---|---|---|
| Q02 | `080ebc00-3644-4719-b6e6-6f855604f6b6` | `PASS` |
| Q04 | `f8e8a8d4-48c8-4c30-a7f0-2eace7bb8ccb` | `PASS_SOFT` |
| Q05 | `dcf243dd-7948-414b-a1ad-9481f83a5445` | `PASS` |
| Q06 | `f1147d03-5c9b-4874-ba86-0406e1a90bdc` | `INFRA_FAIL` |

The Q06 aggregate was invalid with `summary_missing`, no timeout, and no report.
It wrote host-keyed evidence under `Q06/USDJPY_DWX/aggregate.json`, showing the
runner did not preserve the logical basket label.

## Code Fix

- `framework/scripts/q06_stress_harsh.py` now accepts `--logical-symbol`, writes
  aggregate evidence under the logical basket label, records `runner_symbol`,
  passes basket tester currency/deposit overrides from `basket_manifest.json`,
  and uses the same 3300-second tester budget plus 120-second wrapper headroom
  as Q05.
- Q06 also infers the logical basket symbol from `basket_manifest.json` when an
  already-running worker invokes it without the new flag.
- `tools/strategy_farm/farmctl.py` now passes `--logical-symbol` for Q06 basket
  rows, matching Q04/Q05 behavior.

## Queue Action

Requeued the existing Q06 row in place:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12781 --phase Q06
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `f1147d03-5c9b-4874-ba86-0406e1a90bdc` |
| Created rows | `0` |
| Status after worker claim | `done` |
| Verdict after worker claim | `INFRA_FAIL` |
| Archived prior report root | `D:\QM\reports\work_items\f1147d03-5c9b-4874-ba86-0406e1a90bdc.requeued_20260630T1921440000` |

Verified runner command includes:

```text
q06_stress_harsh.py --symbol USDJPY.DWX --logical-symbol QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1
```

The paced worker claimed the row after requeue. The fresh aggregate is now
logical-basket keyed:

```text
D:\QM\reports\work_items\f1147d03-5c9b-4874-ba86-0406e1a90bdc\QM5_12781\Q06\QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1\aggregate.json
```

Fresh aggregate result:

- `symbol`: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- `runner_symbol`: `USDJPY.DWX`
- `verdict`: `INVALID`
- `reason`: `summary_missing`
- `timed_out`: `false`
- `timeout_sec`: `3300`
- `runner_timeout_sec`: `3420`
- `exit_code`: `3221225794`

This confirms the basket evidence bridge is fixed. The remaining Q06 failure is
still infrastructure-level and non-timeout; no additional duplicate requeue was
inserted without a new terminal/process-launch fix.

## Validation

```text
python -m py_compile framework/scripts/q06_stress_harsh.py tools/strategy_farm/farmctl.py
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_cascade_real_phase_runners.py -q
```

Result:

- `32 passed, 2 subtests passed`

## Safety

- No `T_Live` access.
- AutoTrading not toggled.
- No portfolio admission, portfolio KPI, or Q08 contribution files touched.
- No manual MT5 tester run launched; the Q06 row was left to paced workers and
  completed as the non-timeout INFRA result above.
