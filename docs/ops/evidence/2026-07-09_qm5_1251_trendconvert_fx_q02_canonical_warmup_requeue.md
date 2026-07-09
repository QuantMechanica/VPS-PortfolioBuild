# QM5_1251 FX Q02 Canonical Warmup Requeue - 2026-07-09

## Scope

- EA: `QM5_1251_carver-trendconvert`
- Unit of work: Q02 infra repair for the six FX D1 legs already pending in the farm DB.
- Symbols: `AUDUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDJPY.DWX`
- Diversity rationale: FX D1 Carver trend-conversion strategy, outside the current index/metal/energy survivor cluster.

## Diagnosis

The approved backlog still did not contain a valid higher-diversity build target: the remaining rates/commodity cards require unavailable/custom external data, and the available unbuilt card targets index/metal. The best diverse throughput unit was therefore the pending `QM5_1251` Q02 infra queue.

The EA performs intentional D1 basket reads across all 12 declared symbols, but `OnInit` still left the framework's default single-symbol guard in place and did not warm the basket history before tester execution. The pending Q02 rows also referenced legacy setfile names that do not match the current canonical EA-folder setfile pattern.

## Repair

- Added `QM_SymbolGuardInit(g_symbols)` after `QM_FrameworkInit`.
- Added `QM_BasketWarmupHistory(g_symbols, PERIOD_D1, warmup_bars)` using the strategy conversion/EMA warmup depth.
- Moved the no-op news hook after Friday-close, management, and strategy exits, so future news gating cannot block protective actions.
- Generated canonical fixed-risk backtest setfiles for the six FX legs:
  - `QM5_1251_carver-trendconvert_AUDUSD.DWX_D1_backtest.set`
  - `QM5_1251_carver-trendconvert_EURUSD.DWX_D1_backtest.set`
  - `QM5_1251_carver-trendconvert_GBPUSD.DWX_D1_backtest.set`
  - `QM5_1251_carver-trendconvert_NZDUSD.DWX_D1_backtest.set`
  - `QM5_1251_carver-trendconvert_USDCAD.DWX_D1_backtest.set`
  - `QM5_1251_carver-trendconvert_USDJPY.DWX_D1_backtest.set`

## Verification

- Framework guardrail: `build_check.result=PASS`, `failures=0`, `warnings=0`.
- Compile: `PASS`, `0` errors, `0` warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260709_170736.json`
- Compile log: `C:\QM\repo\framework\build\compile\20260709_170736\QM5_1251_carver-trendconvert.compile.log`
- Backtests were not run in this unit.
- No `T_Live`, live manifest, portfolio gate, or AutoTrading state was touched.

## Farm DB

- DB backup before retarget: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1251_q02_canonical_requeue_20260709T170819Z.sqlite`
- Existing pending Q02 rows were retargeted in place to canonical setfiles; no duplicate Q02 rows were created.

| Symbol | Work item id | Phase | Status |
|---|---|---|---|
| `AUDUSD.DWX` | `5b203cc2-584e-4447-9e4d-820cf6a2a49f` | Q02 | pending |
| `EURUSD.DWX` | `9a6e221f-d41f-4f1c-a25e-eadb372e474c` | Q02 | pending |
| `GBPUSD.DWX` | `d5ea44d4-ef70-481b-84c1-769f6da0b0c4` | Q02 | pending |
| `NZDUSD.DWX` | `0e41e362-7dcc-432e-839f-d24288afb5da` | Q02 | pending |
| `USDCAD.DWX` | `7cbf1195-22b8-4619-bb25-ba0860d288ab` | Q02 | pending |
| `USDJPY.DWX` | `fbd59c95-bd7b-41cf-8d08-8ca47abf1d14` | Q02 | pending |
