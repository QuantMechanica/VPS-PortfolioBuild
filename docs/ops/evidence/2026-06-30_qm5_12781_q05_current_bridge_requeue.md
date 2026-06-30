# QM5_12781 Q05 Current-Bridge Requeue

Date: 2026-06-30
Branch: `agents/board-advisor`

## Scope

Fallback path for the FX portfolio mission. The local 66-pair scan rerun has no
unbuilt positive-hedge EdgeLab FX cointegration pair left: all 29 ranked
positive-hedge pairs are already represented in `framework/EAs`.

The strict survivors were checked first:

- `QM5_12532` AUDUSD/NZDUSD: logical-basket Q02 `PASS`; later phases already reached.
- `QM5_12533` EURJPY/GBPJPY: logical-basket Q02 `PASS`; later phases already reached.

Selected existing forex sleeve:

- EA: `QM5_12781_edgelab-usdjpy-audjpy-cointegration`
- Logical basket: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- Host/run symbol: `USDJPY.DWX`
- Phase advanced: Q05 stress medium

## Prior State

`QM5_12781` had already reached:

| Phase | Work item | Status | Verdict |
|---|---|---|---|
| Q02 | `080ebc00-3644-4719-b6e6-6f855604f6b6` | done | `PASS` |
| Q04 | `f8e8a8d4-48c8-4c30-a7f0-2eace7bb8ccb` | done | `PASS_SOFT` |
| Q05 | `dcf243dd-7948-414b-a1ad-9481f83a5445` | done | `INFRA_FAIL` |

The Q05 aggregate was infrastructure-invalid, not a strategy failure:

```text
reason=summary_missing
runner_symbol=USDJPY.DWX
summary_path=null
report_path=null
timed_out=false
```

The prior Q05 worker log showed the spawned command omitted the logical basket
label:

```text
q05_stress_medium.py ... --symbol USDJPY.DWX --baseline-setfile ...
```

Current repo code now resolves the same row to the corrected Q05 basket bridge:

```text
q05_stress_medium.py
  --symbol USDJPY.DWX
  --logical-symbol QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1
  --baseline-setfile C:\QM\repo\framework\EAs\QM5_12781_edgelab-usdjpy-audjpy-cointegration\sets\QM5_12781_edgelab-usdjpy-audjpy-cointegration_QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set
```

## Queue Action

Requeued the existing Q05 row in place:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12781 --phase Q05
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `dcf243dd-7948-414b-a1ad-9481f83a5445` |
| Created rows | `0` |
| Status after | `pending` |
| Verdict after | `null` |
| Duplicate pending/active Q05 rows | `1` |
| Archived prior report root | `D:\QM\reports\work_items\dcf243dd-7948-414b-a1ad-9481f83a5445.requeued_20260630T1535320000` |

## Validation

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12781
Q02 done PASS; Q04 done PASS_SOFT; Q05 pending

python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -k "q05_runner_cmd_receives_latest_full_year_cap or q05_accepts_q04_soft_pass_verdicts" tools/strategy_farm/tests/test_cascade_real_phase_runners.py::CascadeRealPhaseRunnerTests::test_q04_basket_dispatch_uses_host_symbol_and_keeps_logical_label -q
2 passed, 11 deselected, 2 subtests passed
```

No manual MT5 backtest was launched. The pending Q05 is left for paced factory
workers.

## Safety

- No `T_Live` manifest touched.
- AutoTrading not toggled.
- No portfolio gate, `portfolio_admission`, `portfolio_kpi`, or
  `q08_contribution` artifact touched.
- Q05 remains a RISK_FIXED backtest queue item.
