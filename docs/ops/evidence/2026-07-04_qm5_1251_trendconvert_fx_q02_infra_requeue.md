# QM5_1251 FX Q02 Infra Requeue - 2026-07-04

## Scope

- EA: `QM5_1251_carver-trendconvert`
- Unit of work: Q02 infra repair plus farm enqueue for the six FX D1 legs.
- Symbols: `AUDUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDJPY.DWX`
- Diversity rationale: FX D1 Carver trend-conversion strategy, outside the current index/metal/energy survivor cluster.
- Backtest setfiles: existing `RISK_FIXED` D1 backtest setfiles under `framework/EAs/QM5_1251_carver-trendconvert/sets/`.

## Diagnosis

The latest Q02 work items for the six FX legs were `INFRA_FAIL` with retries exhausted and no active/pending `QM5_1251` rows in the farm DB. Local guardrails also showed the EA was not enqueue-ready:

- `EA_FRAMEWORK_RAW_SERIES_CALL` failures on intentional D1 historical `iClose` / `iTime` calls.
- `.DWX` spread-zero advisory on the entry spread filter.

## Repair

- Marked the deliberate D1 closed-bar historical reads as `perf-allowed`; they are part of the structural conversion-score and forecast calculation.
- Changed the spread filter to tolerate zero `.DWX` spread data. The filter now treats only negative spread values as invalid, so zero tester spread no longer blocks entries.
- Recompiled `QM5_1251_carver-trendconvert.ex5`.

## Verification

- Compile: `PASS`, `0` errors, `0` warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260704_005655\QM5_1251_carver-trendconvert.compile.log`
- Framework guardrail: `build_check.result=PASS`, `failures=0`.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260704_005655.json`
- Backtests were not run in this unit.
- No `T_Live`, live manifest, portfolio gate, or AutoTrading state was touched.

## Farm DB

- DB backup before enqueue: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1251_q02_fx_infra_requeue_20260704T005827Z.sqlite`
- Evidence path on new rows: `docs/ops/evidence/2026-07-04_qm5_1251_trendconvert_fx_q02_infra_requeue.md`

| Symbol | Work item id | Phase | Status |
|---|---|---|---|
| `AUDUSD.DWX` | `5b203cc2-584e-4447-9e4d-820cf6a2a49f` | Q02 | pending |
| `EURUSD.DWX` | `9a6e221f-d41f-4f1c-a25e-eadb372e474c` | Q02 | pending |
| `GBPUSD.DWX` | `d5ea44d4-ef70-481b-84c1-769f6da0b0c4` | Q02 | pending |
| `NZDUSD.DWX` | `0e41e362-7dcc-432e-839f-d24288afb5da` | Q02 | pending |
| `USDCAD.DWX` | `7cbf1195-22b8-4619-bb25-ba0860d288ab` | Q02 | pending |
| `USDJPY.DWX` | `fbd59c95-bd7b-41cf-8d08-8ca47abf1d14` | Q02 | pending |
