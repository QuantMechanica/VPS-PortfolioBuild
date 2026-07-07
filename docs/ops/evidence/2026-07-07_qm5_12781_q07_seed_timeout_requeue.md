# QM5_12781 Q07 Seed-Timeout Requeue

Date: 2026-07-07
Branch: `agents/board-advisor`
Operator: Codex

## Scope

Advanced an existing market-neutral FX cointegration basket after confirming no
unbuilt card-worthy FX cointegration pair remained and the named anchors were not
Q02-blocked:

- `QM5_12532`: Q02 `PASS`, Q04 `PASS`, latest Q05 `FAIL`.
- `QM5_12533`: Q02 `PASS`, latest Q04 `FAIL`.
- `QM5_13024`: Q02 `PASS`, latest Q04 `FAIL`.
- `QM5_13029`: Q02 `PASS`, Q03 `PASS`, latest Q04 `FAIL`.

## Action

Selected `QM5_12781` (`USDJPY.DWX~AUDJPY.DWX`) because it already had Q05/Q06
`PASS` and was blocked at Q07 by infra evidence, not a strategy verdict.

Prior Q07 state:

- Work item: `38226031-b41f-4f03-ab86-d1697ca5e203`
- Status/verdict: `done` / `INFRA_FAIL`
- Reason: seed `7` timed out at `2400s`; seeds `42`, `17`, `99`, and `2026`
  were reusable valid summaries with 228 trades and PF 1.07.

Changes:

- Requeued the same Q07 work item with `farmctl enqueue-backtest --ea QM5_12781 --phase Q07`.
- No duplicate work item was created.
- Archived the prior report root to
  `D:/QM/reports/work_items/38226031-b41f-4f03-ab86-d1697ca5e203.requeued_20260707T1503530000`.
- Added `q07_seed_timeout_sec=5400` and priority audit fields to the pending row.
- Patched `tools/strategy_farm/farmctl.py` so Q07 work-item payloads can pass
  `q07_seed_timeout_sec` through to `q07_multiseed.py --timeout-sec`.

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py framework/scripts/q07_multiseed.py`
- `python -m unittest tools.strategy_farm.tests.test_farmctl_cascade.CascadePromotionTests.test_q07_runner_cmd_keeps_basket_logical_symbol`
- `python -m unittest framework.scripts.tests.test_q05_q07_verdicts`
- Direct live-row command build check confirmed `--timeout-sec 5400`.

## Safety

No manual MT5 dispatch was launched. Queue remained saturated at 7 active work
items, so the paced fleet owns the pending Q07 row.

No `T_Live`, AutoTrading, deploy manifest, portfolio admission gate,
`portfolio_admission`, `_kpi`, or `_q08_contribution` file was touched.

Machine artifact:
`artifacts/qm5_12781_q07_requeue_seed_timeout_20260707T150517Z.json`.
