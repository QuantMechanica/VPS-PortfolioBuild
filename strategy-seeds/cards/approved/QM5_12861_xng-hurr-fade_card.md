---
copy_of: strategy-seeds/cards/xng-hurr-fade_card.md
ea_id: QM5_12861
slug: xng-hurr-fade
type: strategy
strategy_id: EIA-NOAA-XNG-HURR-2026_S02
source_id: EIA-NOAA-XNG-HURR-2026
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_12861_XNG_HURR_FADE_D1
period: D1
expected_trade_frequency: "D1 natural-gas hurricane-window failed-spike fade; estimate 3-7 trades/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
---

# XNG Hurricane Failed-Spike Fade

Canonical card: `strategy-seeds/cards/xng-hurr-fade_card.md`.

Approved G0 summary: D1 `XNGUSD.DWX` short-only failed-spike fade inside the
August 15 through October 31 Atlantic hurricane risk window. The EA uses
official EIA/NOAA hurricane energy-market lineage only as structural context;
runtime uses Darwinex MT5 OHLC and broker calendar only.

This is explicitly non-duplicate versus `QM5_12601_eia-xng-hurr-brk` because
that EA buys confirmed upside hurricane-window breakouts, while this EA shorts
failed upside spikes only after bearish D1 rejection. It is also not RSI
pullback, storage, LNG, broad XNG seasonality, weekend-gap, XTI/XNG basket, or
metal/index logic.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single symbol
`XNGUSD.DWX`. No live manifest, AutoTrading, portfolio gate, external runtime
data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial XNG hurricane failed-spike fade build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | `strategy-seeds/cards/xng-hurr-fade_card.md` |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12861_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `93fd0dc3-09a4-479c-bbfd-6c9b8b3922d0` |
