# QM5_12803 USDCAD/EURAUD Cointegration Basket Q02 Enqueue

Date: 2026-06-29

## Scope

- Mission: add a non-duplicate FX market-neutral cointegration sleeve to the V5 funnel.
- `QM5_12532` and `QM5_12533` were checked first; both have later logical-basket Q02 PASS records, so no ONINIT or NO_HISTORY repair was needed before selecting a new pair.
- The controlling research source is `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` plus the rerun of `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`.
- Selected pair: `USDCAD.DWX` / `EURAUD.DWX`, the next unbuilt positive-hedge tail candidate after built baskets through `QM5_12786`.
- Scan metrics: rank `29`, DEV Sharpe `0.5746`, OOS net Sharpe `-0.8728`, OOS return `-5.8413%`, OOS state changes `13`, hedge beta `0.466896958`, half-life `65.82` days.
- This is exploratory and sub-threshold, not one of the two hard survivors.

## Build Evidence

- EA: `framework/EAs/QM5_12803_edgelab-usdcad-euraud-cointegration/QM5_12803_edgelab-usdcad-euraud-cointegration.mq5`
- Card: `strategy-seeds/cards/approved/QM5_12803_edgelab-usdcad-euraud-cointegration_card.md`
- Manifest: `framework/EAs/QM5_12803_edgelab-usdcad-euraud-cointegration/basket_manifest.json`
- Setfile: `framework/EAs/QM5_12803_edgelab-usdcad-euraud-cointegration/sets/QM5_12803_edgelab-usdcad-euraud-cointegration_QM5_12803_USDCAD_EURAUD_COINTEGRATION_D1_D1_backtest.set`
- Build result: `artifacts/qm5_12803_build_result.json`
- Runtime build result: `D:\QM\strategy_farm\artifacts\builds\1827cfa5-fdde-4618-b200-64564bf095d7.json`
- Build task: `1827cfa5-fdde-4618-b200-64564bf095d7`
- Risk mode: backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Compile: `framework/scripts/compile_one.ps1 -Strict` PASS, errors `0`, warnings `0`.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_185345\QM5_12803_edgelab-usdcad-euraud-cointegration.compile.log`
- Symbol scope: `BASKET_OK`, violations `0`; conversion-history references `AUDUSD.DWX` and `EURUSD.DWX` are declared in the manifest.
- Card schema lint: `ok`.
- SPEC validation: PASS.
- Build check: PASS, failures `0`, warnings `16` existing shared-framework DWX advisories.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_185405.json`

## Q02 Enqueue

`farmctl record-build` inserted one logical-basket Q02 work item:

| Field | Value |
|---|---|
| work_item_id | `6c344f79-282d-491c-81c6-2c3b3bd80538` |
| ea_id | `QM5_12803` |
| phase | `Q02` |
| status | `pending` |
| symbol | `QM5_12803_USDCAD_EURAUD_COINTEGRATION_D1` |
| host_symbol | `USDCAD.DWX` |
| timeframe | `D1` |
| tester_currency | `USD` |
| setfile | `framework/EAs/QM5_12803_edgelab-usdcad-euraud-cointegration/sets/QM5_12803_edgelab-usdcad-euraud-cointegration_QM5_12803_USDCAD_EURAUD_COINTEGRATION_D1_D1_backtest.set` |

Verification command `python tools\strategy_farm\farmctl.py work-items --ea QM5_12803`
returned `count: 1` and `summary: { "Q02_pending": 1 }`.

## Guardrails

- No manual MT5 backtest was launched; Q02 execution is left to the paced fleet worker.
- No `T_Live` manifest or AutoTrading action.
- No portfolio admission, portfolio KPI, or Q08 contribution artifact touched.
- No banned or ML indicators; the EA uses a fixed D1 spread z-score, ATR hard stops, broken-package cleanup, and framework guards.
