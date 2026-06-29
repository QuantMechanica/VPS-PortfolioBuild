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
ATR as a percent of price sits inside a fixed corridor. The goal is to add an
energy sleeve whose return driver is not a metals ratio, index trend, short
horizon RSI pullback, or natural-gas calendar/event trigger.

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
- Compute ATR(`strategy_atr_period`) as a percent of the prior completed D1
  close.
- Long package: BUY `XNGUSD.DWX` if momentum is greater than
  `strategy_min_abs_return_pct / 100` and ATR% is between
  `strategy_min_atr_pct` and `strategy_max_atr_pct`.
- Short package: SELL `XNGUSD.DWX` if momentum is less than
  `-strategy_min_abs_return_pct / 100` and ATR% is between the same fixed
  corridor.
- No entry if return is inside the neutral band, ATR% is outside the corridor,
  spread exceeds `strategy_max_spread_points`, or a position is already open for
  this EA magic.
- Exit any open package on the next monthly rebalance bar or after
  `strategy_max_hold_days` calendar days.
- Stop loss is fixed at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-8 entries/year.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only; no futures
  curve, inventory feed, EIA feed, weather feed, CSV, API, analyst forecast, or
  ML model.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when D1 history is shorter than `strategy_momentum_lookback_d1`
  plus warmup bars.
- Skip entries when ATR or close data is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_momentum_lookback_d1
  default: 252
  sweep_range: [210, 252, 294]
- name: strategy_min_abs_return_pct
  default: 1.0
  sweep_range: [0.5, 1.0, 2.0, 3.5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 4.5]
- name: strategy_min_atr_pct
  default: 0.75
  sweep_range: [0.5, 0.75, 1.0]
- name: strategy_max_atr_pct
  default: 10.0
  sweep_range: [7.5, 10.0, 12.5]
- name: strategy_max_hold_days
  default: 31
  sweep_range: [21, 31, 45]
- name: strategy_max_spread_points
  default: 1500
  sweep_range: [1000, 1500, 2500]

## Author Claims

No source performance number is imported into QM. The source is used only for
structural lineage around time-series momentum across futures and commodity
markets. The Q02+ pipeline tests the mechanical natural-gas port on Darwinex
`XNGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.05
- expected_dd_pct: 22
- expected_trade_frequency: approximately 4-8 entries/year.
- risk_class: high.
- gridding: false.
- scalping: false.
- ml_required: false.

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

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, monthly rebalance gate, and ATR% corridor.
- trade_entry: monthly 12-month D1 return-sign long/short package gated by
  current ATR as percent of price.
- trade_management: monthly package flattening and max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-29 | initial structural natural-gas volatility-gated TSMOM build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
