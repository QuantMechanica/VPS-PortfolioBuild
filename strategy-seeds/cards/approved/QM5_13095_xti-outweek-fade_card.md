---
ea_id: QM5_13095
slug: xti-outweek-fade
type: strategy
strategy_id: CRABEL-WTI-OUTWEEK-REV-2026
source_id: CRABEL-WTI-OUTWEEK-REV-2026
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990; U.S. Energy Information Administration. What drives crude oil prices: Spot Prices. URL https://www.eia.gov/finance/markets/crudeoil/spot_prices.php."
source_citations:
  - type: book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Short-term price-pattern and range-expansion lineage, ported to D1 WTI outside-week exhaustion."
    quality_tier: A
    role: primary
  - type: official
    citation: "U.S. Energy Information Administration. What drives crude oil prices: Spot Prices."
    location: "https://www.eia.gov/finance/markets/crudeoil/spot_prices.php"
    quality_tier: A
    role: market_context
sources:
  - "[[sources/CRABEL-WTI-OUTWEEK-REV-2026]]"
  - "[[sources/EIA-CRUDE-SPOT-PRICES]]"
concepts:
  - "[[concepts/outside-week-exhaustion]]"
  - "[[concepts/weekly-range-reversal]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [outside-week, exhaustion-fade, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13095_XTI_OUTWEEK_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI outside-week exhaustion fade; estimate 8-16 trades/year after outside-week, close-location, reversal, range, spread, and one-entry-per-week filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS Crabel price-pattern source plus official EIA WTI market context; R2 PASS deterministic D1 outside-week exhaustion fade with ATR/SMA/close-location confirmation, ATR stop/target, failed-fade and max-hold exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI Outside-Week Exhaustion Fade

## Hypothesis

Crabel's short-term price-pattern lineage treats range expansion as a structural
reference point. This card uses that lineage in a low-frequency WTI sleeve: a
fully completed broker week must be an outside week versus the prior broker
week, and the following week must show D1 reversal evidence back toward the
parent range before the EA fades the outside-week close extreme.

This is intended to add solo crude-oil exposure to the current XAU/SP500/NDX/XNG
book without adding another gold, index, or XNG RSI-like sleeve.

## Source

Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
Breakout*. Traders Press, 1990. Supplemental market context: U.S. Energy
Information Administration, "What drives crude oil prices: Spot Prices", URL
https://www.eia.gov/finance/markets/crudeoil/spot_prices.php.

No source performance claim is imported. The sources provide only price-pattern
lineage and WTI market context; Q02 validates the deterministic Darwinex
implementation.

## Concept

The strategy uses only Darwinex `XTIUSD.DWX` OHLC, broker calendar time, ATR,
SMA, current spread, and V5 framework state. It does not read a futures curve,
inventory feed, WPSR, OPEC release, refinery statistic, hurricane feed, rig
count, CFTC data, EIA API, CME data, volume, open interest, CSV, analyst
forecast, or discretionary runtime data.

This is deliberately different from:

- `QM5_12965_wti-week-orb`: weekly opening-range breakout from the first D1 bar
  of the current broker week.
- `QM5_13075_xti-inweek-brk`: inside-week compression breakout. This card
  requires an outside week and fades exhaustion after reversal confirmation.
- `QM5_12752_eia-wti-wpsr-idbrk`: post-WPSR inside-bar event breakout. This
  card uses no WPSR/event window and its setup unit is a completed broker week.
- WTI weekend-gap fade/bounce cards: this card does not use the weekend gap.
- Fixed WTI weekday/month cards: this card requires weekly outside-range
  expansion and reversal evidence, not calendar arrival alone.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll,
  driving-season, distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold,
  oil/silver, XAU/XAG, XNG sleeves, and `QM5_12567_cum-rsi2-commodity`: no
  event data, ratio, storage, futures curve, RSI, or multi-leg basket is used.

## Target Symbols And Period

- Target symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: 8-16 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

The EA is a symmetric D1 outside-week fade. It builds the previous two completed
broker weeks from closed D1 bars, confirms that the most recent completed week
expanded beyond both sides of its parent week, classifies the outside-week close
as upper-tail or lower-tail exhaustion, and waits for the current week to print
a confirming reversal bar. It then opens one market position in the fade
direction, with fixed ATR stop/target, failed-fade exits, profitable SMA mean
reach exits, max-hold exit, spread cap, and framework Friday close.

## Entry

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Identify the broker week containing the prior completed D1 bar.
- The immediately preceding completed broker week must be an outside week:
  its high is above the high of the week before it and its low is below the low
  of the week before it.
- Require both the outside week and parent week to have at least
  `strategy_min_week_bars` completed D1 bars.
- Require the outside-week range to be between
  `strategy_min_outside_range_atr * ATR(strategy_atr_period)` and
  `strategy_max_outside_range_atr * ATR(strategy_atr_period)`.
- Require the parent-week range to be at least
  `strategy_min_parent_range_atr * ATR(strategy_atr_period)`.
- Signal bars are allowed only when the prior completed D1 bar's day-of-week is
  between `strategy_signal_min_dow` and `strategy_signal_max_dow`, default
  Monday through Thursday.
- Entry Long: outside week closed in the lower tail, outside close is below
  SMA(`strategy_trend_period`), the signal bar is bullish, closes in the upper
  portion of its D1 range, and reclaims the greater of the parent-week low or
  the outside-week low plus ATR buffer.
- Entry Short: outside week closed in the upper tail, outside close is above
  SMA(`strategy_trend_period`), the signal bar is bearish, closes in the lower
  portion of its D1 range, and reclaims below the lesser of the parent-week high
  or the outside-week high minus ATR buffer.
- Allow at most one entry per broker week.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit

- Exit Long if a completed D1 close fails back below the outside-week low.
- Exit Short if a completed D1 close fails back above the outside-week high.
- Exit a profitable Long when the completed D1 close reaches or exceeds
  SMA(`strategy_trend_period`).
- Exit a profitable Short when the completed D1 close reaches or falls below
  SMA(`strategy_trend_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Framework Friday close remains enabled.

## Stop

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- No pyramiding, no gridding, no martingale, no partial close, and no trailing
  stop in v1.

## Parameters To Test

- name: strategy_min_week_bars
  default: 3
  sweep_range: [3, 4]
- name: strategy_signal_min_dow
  default: 1
  sweep_range: [1, 2]
- name: strategy_signal_max_dow
  default: 4
  sweep_range: [3, 4]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_min_outside_range_atr
  default: 1.20
  sweep_range: [0.90, 1.20, 1.60]
- name: strategy_max_outside_range_atr
  default: 4.50
  sweep_range: [3.50, 4.50, 5.50]
- name: strategy_min_parent_range_atr
  default: 0.80
  sweep_range: [0.60, 0.80, 1.10]
- name: strategy_reclaim_buffer_atr
  default: 0.15
  sweep_range: [0.08, 0.15, 0.25]
- name: strategy_extreme_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.72]
- name: strategy_min_reversal_close_location
  default: 0.58
  sweep_range: [0.55, 0.58, 0.65]
- name: strategy_atr_sl_mult
  default: 2.80
  sweep_range: [2.20, 2.80, 3.40]
- name: strategy_atr_tp_mult
  default: 2.20
  sweep_range: [1.80, 2.20, 2.80]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [6, 10, 15]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 8-16 trades/year.
- risk_class: medium-high for crude-oil overnight and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Crabel trading book lineage plus official EIA WTI
  context.
- [x] R2 mechanical: fixed weekly outside-week definition, ATR/SMA
  confirmation, close-location confirmation, ATR stop/target, failed-fade, and
  max-hold exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: WTI outside-week exhaustion fade is not WTI weekly ORB,
  inside-week breakout, monthly ORB, WPSR inside-bar event breakout, weekend
  gap, fixed weekday/month anomaly, event sleeve, broad TSMOM/reversal,
  ratio basket, VRP proxy, or commodity RSI pullback.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, and signal-day guard.
- trade_entry: outside-week exhaustion fade with ATR reclaim buffer, SMA stretch
  context, close-location confirmation, and one-entry-per-week guard.
- trade_management: failed-fade exit, profitable SMA mean-reach exit, ATR
  target/stop, and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial structural WTI outside-week exhaustion fade build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
