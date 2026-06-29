# QM5_12765 GBPUSD/NZDUSD Q02 Enqueue - 2026-06-29

## Scope

- Mission: grow the V5 book with non-duplicate FX market-neutral cointegration sleeves.
- Checked first: `QM5_12532` and `QM5_12533` both already have logical-basket Q02 `PASS` rows in `D:/QM/strategy_farm/state/farm_state.sqlite`.
- Existing EdgeLab FX cointegration baskets already cover all OOS-positive tail pairs through rank 18. The selected new pair is rank 19 by OOS net Sharpe: `GBPUSD.DWX` / `NZDUSD.DWX`.
- Caveat: this is not a hard survivor. Rerun metrics were DEV Sharpe `0.6440`, OOS net Sharpe `-0.0426`, OOS return `-0.3222%`, 17 OOS state changes, beta `0.832501`, half-life `25.86d`.

## Build Evidence

- EA: `QM5_12765_edgelab-gbpusd-nzdusd-cointegration`.
- Logical symbol: `QM5_12765_GBPUSD_NZDUSD_COINTEGRATION_D1`.
- Build task: `739e6501-57fd-410e-8e27-85aa11ca9f1b`.
- Compile command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12765_edgelab-gbpusd-nzdusd-cointegration/QM5_12765_edgelab-gbpusd-nzdusd-cointegration.mq5 -Strict`.
- Compile result: `PASS`, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_045046\QM5_12765_edgelab-gbpusd-nzdusd-cointegration.compile.log`.
- Build-check result: `PASS`, 0 failures, 16 existing shared-framework advisory warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_045057.json`.
- Spec validation: `PASS`.
- Build result: `D:\QM\strategy_farm\artifacts\builds\739e6501-57fd-410e-8e27-85aa11ca9f1b.json`.

## Q02 Enqueue

`farmctl record-build` inserted exactly one logical-basket Q02 work item:

| Field | Value |
|---|---|
| work_item_id | `735a3ca6-6012-4897-8603-9ec5353b11d9` |
| ea_id | `QM5_12765` |
| phase | `Q02` |
| status | `pending` |
| symbol | `QM5_12765_GBPUSD_NZDUSD_COINTEGRATION_D1` |
| host_symbol | `GBPUSD.DWX` |
| tester_currency | `USD` |
| setfile | `framework/EAs/QM5_12765_edgelab-gbpusd-nzdusd-cointegration/sets/QM5_12765_edgelab-gbpusd-nzdusd-cointegration_QM5_12765_GBPUSD_NZDUSD_COINTEGRATION_D1_D1_backtest.set` |

No per-leg Q02 fanout was created. No manual MT5 backtest was launched. Q02
execution is left to the paced fleet worker. At enqueue verification, Q02
pending count was `5488`, below the documented 7000 queue ceiling.

No `T_Live`, AutoTrading, portfolio gate, `portfolio_admission`, portfolio KPI,
or Q08 contribution artifact was touched.
