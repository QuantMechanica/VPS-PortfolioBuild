# QM5_12781 Q07 Report-Latch Fix and Requeue

Date: 2026-07-01
Branch: `agents/board-advisor`

## Scope

Mission fallback path was used. The controlling FX scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`: the only strict
66-pair survivors are already built as `QM5_12532` and `QM5_12533`, and neither
is currently Q02-blocked.

Selected existing forex basket:

- EA: `QM5_12781_edgelab-usdjpy-audjpy-cointegration`
- Logical basket: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- Host/run symbol: `USDJPY.DWX`
- Phase advanced: Q07 multi-seed

## Prior State

`QM5_12781` had already reached:

| Phase | Work item | Verdict |
|---|---|---|
| Q02 | `080ebc00-3644-4719-b6e6-6f855604f6b6` | `PASS` |
| Q04 | `f8e8a8d4-48c8-4c30-a7f0-2eace7bb8ccb` | `PASS_SOFT` |
| Q05 | `dcf243dd-7948-414b-a1ad-9481f83a5445` | `PASS` |
| Q06 | `f1147d03-5c9b-4874-ba86-0406e1a90bdc` | `PASS` |
| Q07 | `38226031-b41f-4f03-ab86-d1697ca5e203` | `INFRA_FAIL` |

The Q07 aggregate showed seed 42 and seed 17 completed with 228 trades and
PF 1.07, but seeds 99, 7, and 2026 were invalid with `NO_HISTORY` /
empty-report markers. The seed 99 tester log contained a full successful MT5
completion before a second automatic no-history pass overwrote the report.

## Code Fix

- `framework/scripts/run_smoke.ps1` now latches the first complete valid tester
  report while MT5 is still running, then stops the terminal before a later
  automatic no-history pass can overwrite that report.
- `framework/scripts/q07_multiseed.py` now passes basket manifest tester
  currency/deposit overrides and records `runner_symbol` separately from the
  logical basket symbol.
- `tools/strategy_farm/farmctl.py` now passes `--logical-symbol` to Q07 basket
  runners, matching Q04/Q05/Q06 behavior.

## Queue Action

Command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12781 --phase Q07
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `38226031-b41f-4f03-ab86-d1697ca5e203` |
| Created rows | `0` |
| Status after | `pending` |
| Verdict after | `null` |
| Archived prior report root | `D:\QM\reports\work_items\38226031-b41f-4f03-ab86-d1697ca5e203.requeued_20260701T0206460000` |

Payload retained basket context:

- `portfolio_scope`: `basket`
- `logical_symbol`: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- `host_symbol`: `USDJPY.DWX`
- `host_timeframe`: `D1`
- `tester_currency`: `USD`
- `tester_deposit`: `100000`

## Validation

```text
pwsh parser check for framework/scripts/run_smoke.ps1
python -m py_compile framework/scripts/q07_multiseed.py tools/strategy_farm/farmctl.py
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_q07_runner_cmd_keeps_basket_logical_symbol tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_q06_runner_cmd_keeps_basket_logical_symbol -q
python -m pytest tools/strategy_farm/tests/test_cascade_real_phase_runners.py -q
python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -q
```

Results:

- PowerShell parse: `parse-ok`
- Py compile: PASS
- Focused stress/farmctl tests: `16 passed`
- Cascade real phase runner tests: `6 passed`
- Farmctl cascade tests: `14 passed, 2 subtests passed`

## Safety

- No manual MT5 tester run launched.
- No AutoTrading toggle.
- No portfolio gate, `portfolio_admission`, `portfolio_kpi`, or
  `q08_contribution` files touched.
- No deploy manifest edited.
