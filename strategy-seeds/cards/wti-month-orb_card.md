---
ea_id: QM5_12810
slug: wti-month-orb
type: strategy
source_id: CME-WTI-MONTH-ORB-2026
strategy_id: CME-WTI-MONTH-ORB-2026
source_citations:
  - type: book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Opening-range breakout concept"
    quality_tier: A
    role: primary
  - type: exchange
    citation: "CME Group. Light Sweet Crude Oil Futures contract specifications."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html"
    quality_tier: A
    role: supplement
  - type: exchange
    citation: "CME Group. Chapter 200 Light Sweet Crude Oil Futures."
    location: "https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/CME-WTI-MONTH-ORB-2026]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/monthly-contract-cycle]]"
  - "[[concepts/wti-futures]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [calendar-seasonality, opening-range-breakout, volatility-expansion, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI month-opening range breakout; estimate 6-10 trades/year after ATR range, SMA, close-location, one-trade-per-month, and spread filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS Crabel opening-range source plus CME WTI contract sources; R2 PASS deterministic monthly first-five-D1-bar breakout rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# WTI Monthly Opening Range Breakout

## Source

- Primary source: Crabel, Toby. *Day Trading with Short-Term Price Patterns and
  Opening Range Breakout*. Traders Press, 1990.
- Supplement: CME Group, "Light Sweet Crude Oil Futures contract
  specifications", URL
  https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html.
- Supplement: CME Group, "Chapter 200 Light Sweet Crude Oil Futures", URL
  https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf.

## Concept

WTI crude has a recurring listed-futures contract cycle and enough monthly
hedging, roll, and allocation activity to make a month-opening price range a
useful structural reference. This card ports the opening-range breakout idea to
`XTIUSD.DWX` by defining the first five completed D1 bars of each calendar
month as the range, then trading only a confirmed close outside that range
during the same month.

This is deliberately different from:

- `QM5_12600_cme-wti-exp-brk`: this card uses the month-opening range, not the
  WTI expiry/roll window.
- Fixed WTI weekday/month cards such as `wti-mon-fade`, `wti-wed-prem`,
  `wti-thu-prem`, `wti-feb-prem`, `wti-mar-prem`, `wti-apr-prem`,
  `wti-aug-prem`, `wti-oct-fade`, `wti-nov-fade`, and `wti-dec-fade`: this
  card does not enter because a fixed weekday or calendar month arrived.
- EIA, OPEC, hurricane, refinery, WPSR, driving-season, jet-fuel, and SPR
  sleeves: this card uses no event calendar or external fundamental data.
- `QM5_12563`, `QM5_12603`, `QM5_12616`, `QM5_12708`, `QM5_12710`, and
  `QM5_12711`: this card uses a monthly opening range, not continuous
  Donchian or time-series momentum.
- `QM5_12567_cum-rsi2-commodity`: no RSI or pullback oscillator logic.
- Ratio baskets such as XTI/XNG, oil/gold, oil/silver, and XAU/XAG: this is a
  single-symbol WTI sleeve.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 6-10 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, volume, open interest, CSV, API, analyst forecast, or ML
  model.

## Entry Rules

- Evaluate only on a new D1 bar.
- For the month containing the prior closed D1 bar, identify the first
  `strategy_opening_days` completed D1 bars.
- Define `opening_high` and `opening_low` from those first bars.
- Do not trade until at least one later D1 bar has closed after the opening
  window.
- Require the opening range to be between
  `strategy_min_open_range_atr * ATR(strategy_atr_period)` and
  `strategy_max_open_range_atr * ATR(strategy_atr_period)`.
- Entry Long: the prior close is above
  `opening_high + strategy_entry_buffer_atr * ATR`, above
  SMA(`strategy_trend_period`), and closes in the top
  `strategy_min_close_location` fraction of the D1 range.
- Entry Short: the prior close is below
  `opening_low - strategy_entry_buffer_atr * ATR`, below
  SMA(`strategy_trend_period`), and closes in the bottom range fraction.
- Allow at most one entry package per calendar month.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- Exit Long if the prior close falls back below the monthly `opening_high` or
  below SMA(`strategy_trend_period`).
- Exit Short if the prior close rises back above the monthly `opening_low` or
  above SMA(`strategy_trend_period`).
- Exit any remaining position when the prior closed D1 bar belongs to a new
  calendar month relative to the position open time.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on `D1`.
- Skip entries when ATR, SMA, opening range, close location, tick size, or
  prices are unavailable.
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

- name: strategy_opening_days
  default: 5
  sweep_range: [3, 5, 7]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_min_open_range_atr
  default: 0.60
  sweep_range: [0.45, 0.60, 0.80]
- name: strategy_max_open_range_atr
  default: 4.00
  sweep_range: [3.00, 4.00, 5.00]
- name: strategy_entry_buffer_atr
  default: 0.08
  sweep_range: [0.04, 0.08, 0.12]
- name: strategy_min_close_location
  default: 0.58
  sweep_range: [0.55, 0.58, 0.65]
- name: strategy_atr_sl_mult
  default: 2.50
  sweep_range: [2.00, 2.50, 3.25]
- name: strategy_atr_tp_mult
  default: 4.00
  sweep_range: [3.00, 4.00, 5.00]
- name: strategy_max_hold_days
  default: 15
  sweep_range: [10, 15, 20]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No source performance claim is imported into QM. The sources are used only for
structural lineage around opening-range breakouts and the tradeable CME WTI
futures contract. Q02+ must validate this deterministic Darwinex
`XTIUSD.DWX` realization.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-10 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Crabel opening-range breakout source plus CME
  exchange sources for WTI contract lineage.
- [x] R2 mechanical: fixed first-five-D1-bar monthly opening range, ATR/SMA
  confirmation, fixed ATR stop/target, time stop, and month-end exit.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: monthly opening-range breakout on WTI, not WTI expiry,
  fixed calendar seasonality, WPSR/event logic, broad trend/reversal, ratio
  basket, or commodity RSI pullback.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap.
- trade_entry: monthly opening-range breakout with ATR buffer, SMA trend
  confirmation, close-location confirmation, and one-entry-per-month guard.
- trade_management: failed-breakout exit, SMA failure exit, new-month exit, ATR
  target/stop, and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial WTI month-opening range breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
