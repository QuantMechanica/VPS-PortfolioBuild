---
ea_id: QM5_12965
slug: wti-week-orb
type: strategy
strategy_id: CRABEL-WTI-WEEK-ORB-2026
source_id: CRABEL-WTI-WEEK-ORB-2026
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
source_citations:
  - type: book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Opening-range breakout concept, ported to a weekly D1 range."
    quality_tier: A
    role: primary
sources:
  - "[[sources/CRABEL-WTI-WEEK-ORB-2026]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/weekly-volatility-expansion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [opening-range-breakout, weekly-range-breakout, volatility-expansion, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12965_XTI_WEEK_ORB_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI weekly opening-range breakout; estimate 16-32 trades/year after range, trend, close-location, spread, and one-entry-per-week filters."
expected_trades_per_year_per_symbol: 24
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS Crabel opening-range breakout source packet; R2 PASS deterministic D1 WTI weekly opening-range breakout with ATR/SMA/close-location confirmation, ATR stop/target, week-change and max-hold exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI Weekly Opening Range Breakout

## hypothesis

Crabel's opening-range breakout concept treats an initial range as a structural
reference for later volatility expansion. This card ports that idea to a
low-frequency WTI sleeve: the first completed `XTIUSD.DWX` D1 bar of each
broker week defines the weekly opening box, and a later D1 close outside that
box is traded as a crude-oil volatility expansion signal.

This is intended to add solo crude-oil exposure to the current XAU/SP500/NDX/XNG
book without adding another outright gold, index, or XNG RSI-like sleeve.

## Source

- Source: [[sources/CRABEL-WTI-WEEK-ORB-2026]]
- Primary citation: Crabel, Toby. *Day Trading with Short-Term Price Patterns
  and Opening Range Breakout*. Traders Press, 1990.

## Concept

The strategy uses only Darwinex `XTIUSD.DWX` OHLC and broker calendar time. It
does not read futures curve, inventory, WPSR, OPEC, refinery, hurricane,
rig-count, CFTC, EIA, CME, volume, open interest, CSV, API, analyst forecast,
or discretionary runtime data.

This is deliberately different from:

- `QM5_12810_wti-month-orb`: monthly first-N-D1-bar opening range; this card
  uses the first completed D1 bar of each broker week.
- `QM5_12791_monday-range-breakout`: FX-only H1 Monday-range breakout; this
  card is `XTIUSD.DWX` D1 only and uses crude-oil ATR/SMA/range filters.
- WTI weekend-gap fade/bounce cards: this card does not use the weekend gap.
- Fixed WTI weekday/month cards such as Monday fade, Wednesday/Thursday/Friday
  premia, and single-month premia/fades: this card requires a breakout outside
  a measured weekly opening range, not just calendar arrival.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll,
  driving-season, distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold,
  oil/silver, XAU/XAG, and XNG sleeves: no event data, ratio, season map,
  storage, futures curve, or multi-leg basket is used.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 16-32 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Identify the broker week containing the prior completed D1 bar.
- Define the weekly opening range from the first `strategy_opening_days`
  completed D1 bars of that broker week. Default is one bar, normally Monday.
- Do not trade until at least one later D1 bar has closed after the opening
  range.
- Signal bars are allowed only when the prior completed D1 bar's day-of-week is
  between `strategy_signal_min_dow` and `strategy_signal_max_dow`, default
  Tuesday through Thursday.
- Require the opening range to be between
  `strategy_min_open_range_atr * ATR(strategy_atr_period)` and
  `strategy_max_open_range_atr * ATR(strategy_atr_period)`.
- Entry Long: prior close is above
  `opening_high + strategy_entry_buffer_atr * ATR`, above
  SMA(`strategy_trend_period`), and closes in the top
  `strategy_min_close_location` fraction of the D1 range.
- Entry Short: prior close is below
  `opening_low - strategy_entry_buffer_atr * ATR`, below
  SMA(`strategy_trend_period`), and closes in the bottom range fraction.
- Allow at most one entry per broker week.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- Exit Long if a completed D1 close falls back below the weekly `opening_high`
  or below SMA(`strategy_trend_period`).
- Exit Short if a completed D1 close rises back above the weekly `opening_low`
  or above SMA(`strategy_trend_period`).
- Exit any remaining position when the prior completed D1 bar belongs to a new
  broker week relative to the position open time.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when ATR, SMA, weekly opening range, close location, or prices
  are unavailable.
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
  default: 1
  sweep_range: [1, 2]
- name: strategy_signal_min_dow
  default: 2
  sweep_range: [2]
- name: strategy_signal_max_dow
  default: 4
  sweep_range: [3, 4]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_min_open_range_atr
  default: 0.45
  sweep_range: [0.30, 0.45, 0.65]
- name: strategy_max_open_range_atr
  default: 2.75
  sweep_range: [2.25, 2.75, 3.50]
- name: strategy_entry_buffer_atr
  default: 0.08
  sweep_range: [0.04, 0.08, 0.12]
- name: strategy_min_close_location
  default: 0.60
  sweep_range: [0.55, 0.60, 0.67]
- name: strategy_atr_sl_mult
  default: 2.40
  sweep_range: [2.0, 2.4, 3.0]
- name: strategy_atr_tp_mult
  default: 3.50
  sweep_range: [3.0, 3.5, 4.5]
- name: strategy_max_hold_days
  default: 4
  sweep_range: [3, 4, 5]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No source performance claim is imported into QM. The source is used only for
structural lineage around opening-range breakouts. Q02+ must validate this
deterministic Darwinex `XTIUSD.DWX` realization.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 16-32 trades/year.
- risk_class: medium-high for crude-oil overnight and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Crabel opening-range breakout book source.
- [x] R2 mechanical: fixed weekly opening range, ATR/SMA confirmation, ATR
  stop/target, failed-breakout, week-change, and max-hold exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: weekly WTI opening-range breakout is not monthly ORB,
  FX Monday-range breakout, weekend gap, fixed weekday/month anomaly, event
  sleeve, broad TSMOM/Donchian, ratio basket, or commodity RSI pullback.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, and signal-day guard.
- trade_entry: weekly opening-range breakout with ATR buffer, SMA trend
  confirmation, close-location confirmation, and one-entry-per-week guard.
- trade_management: failed-breakout exit, SMA failure exit, new-week exit,
  ATR target/stop, and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial structural WTI weekly opening-range breakout build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
