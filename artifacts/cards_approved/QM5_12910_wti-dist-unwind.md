---
ea_id: QM5_12910
slug: wti-dist-unwind
type: strategy
strategy_id: EIA-DISTILLATE-CRACK-SEASON-2026_S01
source_id: EIA-DISTILLATE-CRACK-SEASON-2026
source_citation: "U.S. Energy Information Administration. What drives petroleum product prices: Prices and Crack Spreads. URL https://www.eia.gov/finance/markets/products/prices.php"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. What drives petroleum product prices: Prices and Crack Spreads."
    location: "https://www.eia.gov/finance/markets/products/prices.php"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-DISTILLATE-CRACK-SEASON-2026]]"
concepts:
  - "[[concepts/distillate-crack-spread-seasonality]]"
  - "[[concepts/winter-demand-unwind]]"
  - "[[concepts/downside-continuation]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, crack-spread-seasonality, downside-breakdown, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12910_XTI_DIST_UNWIND_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency March-April WTI distillate-crack spring unwind; estimate 4-10 trades/year after breakdown, trend, spread, and framework filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS official EIA petroleum product/crack-spread source; R2 PASS deterministic March-April D1 short breakdown rule with SMA trend gate, ATR hard stop, time/window/channel exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# WTI Distillate Crack Spring Unwind

## Source

- Source: [[sources/EIA-DISTILLATE-CRACK-SEASON-2026]]
- Primary citation: U.S. Energy Information Administration, "What drives
  petroleum product prices: Prices and Crack Spreads", URL
  https://www.eia.gov/finance/markets/products/prices.php.

## Concept

EIA describes distillate crack spreads as seasonally strongest through the
winter heating period because distillate demand rises when heating-oil demand
is high. This card tests the structural unwind after that October-February
product-support window: during March-April, short `XTIUSD.DWX` only when D1
price confirms downside continuation below a slow trend and a recent breakdown
channel.

This is deliberately different from:

- `QM5_12583_eia-distillate-winter`: winter distillate channel-breakout
  continuation. This card waits until after the EIA-defined peak crack-spread
  window and trades short-only unwind, not winter long continuation.
- `QM5_12748_eia-distill-pb`: winter heating-oil pullback long. This card is
  post-winter downside continuation, not an in-season long pullback.
- `QM5_12593_eia-wti-ref-fade`: refinery-turnaround stretch rejection in
  shoulder months. This card uses product crack-spread seasonality, a bearish
  slow-trend gate, and channel breakdown confirmation.
- WTI gasoline driving-season, RBOB, jet-fuel, WPSR, hurricane, Cushing, OPEC,
  expiry, roll, weekday/month, WTI/FX, Brent/WTI, XTI/XNG, oil/gold,
  oil/silver, XNG, XAU/XAG, index, and `QM5_12567_cum-rsi2-commodity` sleeves:
  no event feed, no ratio basket, no RSI, no oscillator pullback, no ML.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected frequency: about 4-10 entries/year before Q02 validates history.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  V5 framework state only. No EIA feed, crack-spread feed, futures curve,
  product inventory feed, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior completed D1 bar must fall inside the March 1 through April 30
  distillate-crack unwind window.
- Host chart must be `XTIUSD.DWX` on D1 with magic slot 0.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Trend gate: prior close must be below SMA(`strategy_trend_period`) and that
  SMA must be below its value `strategy_sma_slope_shift` bars earlier.
- Breakdown trigger: prior close must be below the lowest low of the previous
  `strategy_breakdown_lookback` completed D1 bars, excluding the signal bar,
  and the signal bar must close below its open.
- Entry direction is short only: SELL `XTIUSD.DWX` at market.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close when the active date leaves the March-April unwind window.
- Close when prior completed D1 close recovers above SMA(`strategy_trend_period`).
- Close when prior completed D1 close breaks above the highest high of the
  previous `strategy_exit_channel` completed D1 bars.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when ATR, SMA, channel OHLC, or spread metadata is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short only.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_start_month
  default: 3
  sweep_range: [3]
- name: strategy_start_day
  default: 1
  sweep_range: [1]
- name: strategy_end_month
  default: 4
  sweep_range: [4]
- name: strategy_end_day
  default: 30
  sweep_range: [15, 30]
- name: strategy_trend_period
  default: 63
  sweep_range: [50, 63, 84]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_breakdown_lookback
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_exit_channel
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [8, 12, 18]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The EIA source establishes distillate crack-spread seasonality as structural
lineage only. This card imports no source performance claim. Q02 and later
phases must validate or reject the mechanical rule on Darwinex `XTIUSD.DWX`
bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 4-10 entries/year.
- risk_class: medium-high because crude volatility and low-frequency sample
  size need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA product-price and crack-spread source.
- [x] R2 mechanical: fixed calendar window, bearish SMA trend gate, D1
  breakdown trigger, ATR hard stop, and deterministic window/trend/channel/time
  exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe and D1
  history registry.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not winter distillate long breakout, not winter
  distillate pullback, not refinery shoulder stretch fade, not gasoline/RBOB,
  jet-fuel, WPSR, hurricane, Cushing, OPEC, expiry, roll, weekday/month,
  ratio-basket, XNG, XAU/XAG, index, or commodity RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: XTI/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid data checks.
- trade_entry: March-April distillate-crack unwind D1 downside breakdown.
- trade_management: unwind-window end, trend recovery, short-channel failure,
  and max-hold exits.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial WTI distillate-crack spring unwind card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PENDING | `artifacts/qm5_12910_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | PENDING | `D:\QM\strategy_farm\state\farm_state.sqlite` |
