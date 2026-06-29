---
ea_id: QM5_12804
slug: xng-tsmom12m-atr
type: strategy
source_id: MOP-TSMOM-2012
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. Time Series Momentum. Journal of Financial Economics, 2012. URL https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum"
source_citations:
  - type: paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics."
    location: "AQR/JFE public paper page"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/commodity-trend-premium]]"
  - "[[concepts/volatility-gated-trend]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [intermediate-trend, monthly-rebalance, volatility-filter, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly natural-gas 12-month time-series-momentum package with an ATR% participation gate; estimate 4-8 entries/year after the volatility corridor filters out dormant and shock regimes."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS published JFE/AQR time-series-momentum source across commodities; R2 PASS deterministic monthly natural-gas 12-month return-sign rule plus fixed ATR% volatility corridor, ATR hard stop, and time exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.05
expected_dd_pct: 22.0
---

# Natural Gas 12-Month TSMOM ATR Gate

## Source

- Source: [[sources/MOP-TSMOM-2012]]
- Primary citation: Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H.,
  "Time Series Momentum", Journal of Financial Economics, 2012, URL
  https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## Concept

Time-series-momentum research documents that an asset's own past return can
forecast its next-period directional tendency across futures markets, including
commodities. This card ports the structural premise to the DWX-tradable natural
gas CFD using a 12-month trend horizon, but only participates when current D1
ATR as a percent of price sits inside a fixed corridor.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback
  logic.
- `QM5_12620_comm-reversal-4wk-xngusd`: follows intermediate natural-gas trend
  rather than fading four-week return extremes.
- XNG seasonal, storage, hurricane, freeze, LNG, inventory, weekend-gap, and
  month-of-year sleeves: no weather, EIA, seasonality, weekday, or event
  trigger is used.
- XTI WTI TSMOM sleeves: this trades `XNGUSD.DWX`, not WTI oil.
- XTI/XNG relative-value or basket sleeves: this is a single-symbol structural
  natural-gas trend package, not a spread, ratio, or market-neutral basket.
- XAU/XAG ratio sleeves: this is natural gas, not a metals ratio exposure.

## hypothesis

Natural gas can exhibit persistent directional trends over intermediate
horizons because production, storage, demand, and transport constraints can
adjust slowly. A monthly 12-month return-sign rule should capture this broad
commodity trend premium when realized volatility is neither dormant nor
shock-level.

## rules

- Evaluate only on a new `XNGUSD.DWX` D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Compute `momentum = ln(close_recent / close_past)` using the prior completed
  D1 close and the close `strategy_momentum_lookback_d1` completed bars earlier.
- Trade long above the neutral band, short below the neutral band, and only
  when ATR% is between fixed minimum and maximum bounds.
- Exit on the next monthly rebalance, stale-position guard, or ATR hard stop.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Strategy Allowability Check

- [x] R1 reputable source: published Journal of Financial Economics/AQR paper
  page with single-source lineage.
- [x] R2 mechanical: fixed monthly rebalance, one fixed return lookback, fixed
  ATR% volatility corridor, ATR hard stop, and deterministic time exits.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: volatility-gated 12-month natural-gas trend, not short
  horizon RSI, four-week reversal, XNG weather/storage/calendar/event logic,
  WTI TSMOM, energy basket/ratio, or metals ratio exposure.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
