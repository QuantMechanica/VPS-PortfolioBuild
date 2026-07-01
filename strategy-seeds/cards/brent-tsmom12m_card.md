---
ea_id: QM5_12849
slug: brent-tsmom12m
type: strategy
strategy_id: MOP-TSMOM-2012_BRENT_S01
source_id: MOP-TSMOM-2012
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. Time Series Momentum. Journal of Financial Economics, 2012, 104(2), 228-250."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics, 104(2), 228-250."
    location: "AQR/JFE article page; abstract and publication metadata"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/commodity-trend-premium]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-max-continuation, atr-hard-stop, signal-reversal-exit, time-stop, symmetric-long-short]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly Brent 12-month time-series-momentum package; estimate 8-12 entries/year when the trailing return clears the neutral band."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS published Journal of Financial Economics/AQR source; R2 PASS deterministic monthly 12-month return-sign entry and time exit; R3 PASS XBRUSD.DWX has active local registry/setfile routes through prior Brent work and Q02 validates current history sufficiency; R4 PASS no ML, grid, martingale, external runtime feed, or banned indicators."
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
---

# Brent 12-Month Time-Series Momentum

## Source

- Source: [[sources/MOP-TSMOM-2012]]
- Primary citation: Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H.,
  "Time Series Momentum", Journal of Financial Economics, 2012, 104(2),
  228-250, URL
  https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## Concept

Published time-series-momentum research reports that an instrument's own prior
return can forecast its next-period direction across futures markets, including
commodities. This card ports that structural premise to the DWX-tradable Brent
CFD proxy: once per month, trade `XBRUSD.DWX` in the direction of its prior
12-month D1 return and flatten the package at the next monthly rebalance or
stale-position guard.

This is deliberately different from:

- `QM5_12841_brent-thu-prem`: this card is monthly 12-month return-sign
  momentum, not a one-day Brent weekday premium.
- `QM5_12843_wti-brent-spread` and `QM5_12848_wti-brent-brk`: this is a
  single-symbol Brent directional sleeve, not a Brent/WTI basket.
- `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`,
  `QM5_12844_commodity-trend-crude`, and WTI event/calendar sleeves: this
  trades the Brent benchmark proxy, not XTIUSD WTI.
- `QM5_12804_xng-tsmom12m-atr` and `QM5_12567_cum-rsi2-commodity`: this is
  not natural gas and has no RSI or oscillator pullback logic.
- Existing XAU/XAG baskets and gas-metal baskets: this is pure energy exposure,
  not metal or metal-hedged relative value.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 8-12 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

`XBRUSD.DWX` is queued only for Q02 validation. The local registry already has
Brent routes through `QM5_12841`, `QM5_12843`, and `QM5_12848`, but current
history sufficiency remains a Q02 responsibility.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Compute the prior closed D1 close and the close
  `strategy_momentum_lookback_d1` completed bars earlier.
- Compute `momentum = ln(close_recent / close_past)`.
- Long package: BUY `XBRUSD.DWX` if `momentum` is greater than
  `strategy_min_abs_return_pct / 100`.
- Short package: SELL `XBRUSD.DWX` if `momentum` is less than
  `-strategy_min_abs_return_pct / 100`.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit any open package on the next monthly rebalance bar before considering a
  fresh package for that month.
- Exit any stale package after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XBRUSD.DWX` on D1.
- Skip entries when D1 history is shorter than
  `strategy_momentum_lookback_d1` plus warmup bars.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

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
  sweep_range: [126, 189, 252, 315]
- name: strategy_min_abs_return_pct
  default: 1.0
  sweep_range: [0.0, 1.0, 2.5, 5.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 5.0]
- name: strategy_max_hold_days
  default: 31
  sweep_range: [21, 31, 45]
- name: strategy_max_spread_points
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

The AQR/JFE source states that an instrument's "past 12-month excess return" is
a positive predictor of future return. No source performance number is imported
into QM; Q02 and later phases must validate the mechanical Brent CFD port on
Darwinex `XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 20
- expected_trade_frequency: approximately 8-12 trades/year.
- risk_class: high because Brent CFD history sufficiency and costs need Q02
  proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: published Journal of Financial Economics/AQR paper
  page with single-source lineage.
- [x] R2 mechanical: fixed monthly rebalance, 12-month return-sign direction,
  ATR hard stop, and deterministic time exits.
- [x] R3 testable: `XBRUSD.DWX` has active local Brent routes and Q02 validates
  history sufficiency.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: single-symbol Brent 12-month TSMOM is not Brent weekday,
  Brent/WTI spread, XTI WTI, XNG, XAU/XAG, gas-metal, WTI event/calendar, or
  commodity RSI logic.

## Framework Alignment

- no_trade: D1 and `XBRUSD.DWX` guard, parameter guard, spread cap, and monthly
  rebalance gate.
- trade_entry: monthly 12-month D1 return-sign long/short package.
- trade_management: monthly package flattening and max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial structural Brent 12-month TSMOM build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12849_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `7cc296f9-9603-42a5-ba3e-cccbb8df7792` |
