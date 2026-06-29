# QM5_12764 USDJPY/GBPJPY Q02 Enqueue - 2026-06-29

## Scope

- Mission: grow the V5 book with non-duplicate FX market-neutral cointegration sleeves.
- Original strict survivors `QM5_12532` and `QM5_12533` were checked first; both already have logical-basket Q02 PASS records and are not currently blocked by ONINIT or NO_HISTORY.
- The next available existing forex cointegration basket on this branch was `QM5_12764_edgelab-usdjpy-gbpjpy-cointegration`, the rank-18 OOS-positive tail pair from the same 66-pair scan rerun.

## Build Evidence

- Pair: `USDJPY.DWX` / `GBPJPY.DWX`.
- Logical symbol: `QM5_12764_USDJPY_GBPJPY_COINTEGRATION_D1`.
- Build task: `6876bf40-5fd9-4445-a7b4-b658b895fb88`.
- Compile command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration.mq5 -Strict`.
- Compile result: `PASS`, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_015145\QM5_12764_edgelab-usdjpy-gbpjpy-cointegration.compile.log`.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_015202.json`.
- Build-check result: `PASS`, 0 failures, 16 pre-existing shared-framework advisory warnings.
- Build result: `D:\QM\strategy_farm\artifacts\builds\6876bf40-5fd9-4445-a7b4-b658b895fb88.json`.

## Q02 Enqueue

`farmctl record-build` inserted exactly one logical-basket Q02 work item:

| Field | Value |
|---|---|
| work_item_id | `dea115dd-02b5-4c27-a29f-98013541fc3c` |
| ea_id | `QM5_12764` |
| phase | `Q02` |
| status | `pending` |
| symbol | `QM5_12764_USDJPY_GBPJPY_COINTEGRATION_D1` |
| host_symbol | `USDJPY.DWX` |
| tester_currency | `USD` |
| setfile | `framework/EAs/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration/sets/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration_QM5_12764_USDJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |

No per-leg Q02 fanout was created. No `T_Live`, AutoTrading, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution artifact was touched.
