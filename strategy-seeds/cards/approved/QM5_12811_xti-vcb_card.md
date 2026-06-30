---
ea_id: QM5_12811
slug: xti-vcb
type: strategy
source_id: BOLLINGER-BB-SQUEEZE-2001_XTI
strategy_id: BOLLINGER-BB-SQUEEZE-2001_XTI
source_citations:
  - type: book
    citation: "Bollinger, John. Bollinger on Bollinger Bands. McGraw-Hill, 2001."
    location: "BandWidth and squeeze/volatility-contraction lineage"
    quality_tier: A
    role: primary
  - type: education
    citation: "StockCharts ChartSchool. Bollinger Band Squeeze."
    location: "https://chartschool.stockcharts.com/table-of-contents/trading-strategies-and-models/trading-strategies/bollinger-band-squeeze"
    quality_tier: B
    role: supplement
  - type: exchange
    citation: "CME Group. Light Sweet Crude Oil Futures contract specifications."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/BOLLINGER-BB-SQUEEZE-2001]]"
concepts:
  - "[[concepts/volatility-contraction-breakout]]"
  - "[[concepts/wti-futures]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [volatility-contraction-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Daily WTI volatility-contraction breakout; estimate 6-12 trades/year after BandWidth rank, SMA slope, close-location, spread, and one-position filters."
expected_trades_per_year_per_symbol: 9
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS Bollinger BandWidth/squeeze source plus CME WTI contract source; R2 PASS deterministic D1 BandWidth-rank breakout rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# XTI Volatility-Contraction Breakout

## Source

- Primary source: Bollinger, John. *Bollinger on Bollinger Bands*.
  McGraw-Hill, 2001.
- Supplement: StockCharts ChartSchool, "Bollinger Band Squeeze", URL
  https://chartschool.stockcharts.com/table-of-contents/trading-strategies-and-models/trading-strategies/bollinger-band-squeeze.
- Supplement: CME Group, "Light Sweet Crude Oil Futures contract
  specifications", URL
  https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html.

## Concept

WTI crude regularly alternates between compressed daily ranges and directional
expansion as inventory, refining, macro, and hedging flows reprice the market.
This card uses Bollinger BandWidth as the volatility-contraction measure and
requires a completed D1 close outside the Bollinger envelope to avoid intrabar
noise. A slow SMA level and slope filter keep the breakout aligned with the
prevailing daily drift.

This is deliberately different from:

- `QM5_12810_wti-month-orb`: this card uses a rolling BandWidth squeeze, not
  the first completed bars of a calendar month.
- `QM5_12763_wti-ref-sqz-brk`: this card is non-calendar and symmetric; it is
  not a refinery-ramp window sleeve.
- `QM5_12774_williams-8wk-xti`: this card uses Bollinger BandWidth percentile
  compression and Bollinger-envelope confirmation, not a Williams box.
- `QM5_12780_wti-52w-anchor` and `QM5_12782_katz-seas-xti`: no 52-week anchor,
  no fixed seasonal month/month-pair premise.
- `QM5_12600_cme-wti-exp-brk`, `QM5_12809_eia-jetfuel-brk`, and other WTI
  event/expiry/EIA/OPEC/hurricane/refinery/WPSR sleeves: no event calendar or
  external fundamental data.
- `QM5_12567_cum-rsi2-commodity`: no RSI, pullback oscillator, or multi-asset
  commodity template.
- Ratio baskets such as XAU/XAG, oil/gold, oil/silver, and XTI/XNG: this is a
  single-symbol WTI structural volatility-expansion sleeve.
- `QM5_12804_xng-tsmom12m-atr`, `QM5_12806_xng-rev-weekend`,
  `QM5_12807_xng-52w-anchor`, and other natural-gas sleeves: this is WTI-only
  and uses a different price state variable.
- Index and metal trend/reversal sleeves already in the certified book: this
  targets an energy commodity with distinct supply/demand shocks.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 6-12 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, SMA, Bollinger Bands, and
  broker calendar only; no futures curve, inventory feed, volume, open
  interest, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute Bollinger Bands on completed D1 closes using
  `strategy_bb_period` and `strategy_bb_deviation`.
- Compute current BandWidth as `(upper_band - lower_band) / middle_band` on
  the prior completed D1 bar.
- Rank that BandWidth against the prior `strategy_bandwidth_lookback`
  completed D1 BandWidth observations.
- Require BandWidth rank to be at or below `strategy_bandwidth_rank_max`.
- Entry Long: prior D1 close is above
  `upper_band + strategy_break_buffer_atr * ATR`, above
  SMA(`strategy_trend_period`), SMA slope over
  `strategy_sma_slope_shift` bars is positive, and the close is in the top
  `strategy_close_location_min` fraction of the D1 range.
- Entry Short: prior D1 close is below
  `lower_band - strategy_break_buffer_atr * ATR`, below
  SMA(`strategy_trend_period`), SMA slope over
  `strategy_sma_slope_shift` bars is negative, and the close is in the bottom
  range fraction.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- Exit Long if the prior close falls below the Bollinger middle band or below
  SMA(`strategy_trend_period`).
- Exit Short if the prior close rises above the Bollinger middle band or above
  SMA(`strategy_trend_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on `D1`.
- Skip entries when ATR, SMA, Bollinger values, BandWidth rank, close location,
  tick size, or prices are unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
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

- name: strategy_bb_period
  default: 20
  sweep_range: [18, 20, 24]
- name: strategy_bb_deviation
  default: 2.0
  sweep_range: [1.8, 2.0, 2.2]
- name: strategy_bandwidth_lookback
  default: 126
  sweep_range: [84, 126, 189]
- name: strategy_bandwidth_rank_max
  default: 0.20
  sweep_range: [0.15, 0.20, 0.25]
- name: strategy_trend_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_close_location_min
  default: 0.58
  sweep_range: [0.55, 0.58, 0.65]
- name: strategy_break_buffer_atr
  default: 0.05
  sweep_range: [0.03, 0.05, 0.08]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.25]
- name: strategy_atr_tp_mult
  default: 4.50
  sweep_range: [3.50, 4.50, 5.50]
- name: strategy_max_hold_days
  default: 18
  sweep_range: [12, 18, 25]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No source performance claim is imported into QM. The sources are used only for
structural lineage around Bollinger BandWidth volatility contraction and the
tradeable CME WTI futures contract. Q02+ must validate this deterministic
Darwinex `XTIUSD.DWX` realization.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-12 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Bollinger BandWidth/squeeze source plus CME exchange
  source for WTI contract lineage.
- [x] R2 mechanical: fixed D1 BandWidth rank, fixed Bollinger breakout, SMA
  slope confirmation, fixed ATR stop/target, and time stop.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: WTI-only rolling volatility-contraction breakout, not WTI
  expiry/month/calendar/event logic, natural-gas logic, commodity RSI pullback,
  broad multi-asset trend, or ratio basket.
