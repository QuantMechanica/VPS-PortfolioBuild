# QM5_12762 USDJPY/USDCAD Cointegration Basket Q02 Enqueue

Date: 2026-06-29

## Decision

- `QM5_12532` and `QM5_12533` both have logical-basket Q02 PASS records, so no ONINIT or NO_HISTORY repair was needed first.
- The controlling scan remains `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`; it hard-certified only `EURJPY/GBPJPY` and `AUDUSD/NZDUSD`.
- A rerun of `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py` ranked `USDJPY.DWX` / `USDCAD.DWX` as the next unbuilt OOS-positive tail pair after the existing `12532/12533/12624/12712/12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760` baskets.
- This is sub-threshold exploratory research, not a survivor claim: DEV Sharpe `-0.12`, OOS net Sharpe `0.10`, OOS return `+1.20%`, 15 OOS state changes, hedge `0.196`, and 381-day half-life.

## Build

- EA: `framework/EAs/QM5_12762_edgelab-usdjpy-usdcad-cointegration/QM5_12762_edgelab-usdjpy-usdcad-cointegration.mq5`
- Card: `strategy-seeds/cards/approved/QM5_12762_edgelab-usdjpy-usdcad-cointegration_card.md`
- Manifest: `framework/EAs/QM5_12762_edgelab-usdjpy-usdcad-cointegration/basket_manifest.json`
- Setfile: `framework/EAs/QM5_12762_edgelab-usdjpy-usdcad-cointegration/sets/QM5_12762_edgelab-usdjpy-usdcad-cointegration_QM5_12762_USDJPY_USDCAD_COINTEGRATION_D1_D1_backtest.set`
- Risk mode: backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Compile: `framework/scripts/compile_one.ps1 -Strict` PASS, errors `0`, warnings `0`.
- Build check: `framework/scripts/build_check.ps1 -EALabel QM5_12762_edgelab-usdjpy-usdcad-cointegration -SkipCompile` PASS, failures `0`, warnings `16` existing shared-framework DWX advisories.
- Build-check evidence: `D:/QM/reports/framework/21/build_check_20260629_005228.json`.

## Q02 Handoff

- Work item: `ec04e440-5ee4-440e-b6bc-d78898d233ee`
- Phase: `Q02`
- Status at enqueue verification: `pending`
- Logical symbol: `QM5_12762_USDJPY_USDCAD_COINTEGRATION_D1`
- Host symbol/timeframe: `USDJPY.DWX`, `D1`
- Basket legs: `USDJPY.DWX`, `USDCAD.DWX`
- Tester currency/deposit: `USD`, `100000`
- Timeout: `120` minutes
- Duplicate pending/active count for same EA, phase, and logical symbol: `1`
- DB backup before mutation: `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12762_q02_enqueue_20260629T005304Z.sqlite`

No manual MT5 backtest was launched. Q02 execution is left to the paced fleet worker.

Post-enqueue observation: the paced worker briefly claimed the item on T5 and recorded one `launch_fault`
at `2026-06-29T00:54:26+00:00`; the work item was returned to `pending` with retry metadata and
`launch_not_before_utc=2026-06-29T00:59:26+00:00`. The work-item log file was empty at inspection.

## Guardrails

- No `T_Live` or AutoTrading action.
- No portfolio admission, KPI, or Q08 contribution artifacts touched.
- No banned or ML indicators; the EA uses a fixed D1 spread z-score, ATR hard stops, broken-package cleanup, and framework guards.
