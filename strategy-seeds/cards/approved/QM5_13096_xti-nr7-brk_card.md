---
ea_id: QM5_13096
slug: xti-nr7-brk
type: strategy
strategy_id: CRABEL-WTI-NR7-BRK-2026
source_id: CRABEL-WTI-NR7-BRK-2026
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
source_citations:
  - type: book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Narrow-range price-pattern breakout lineage, ported to D1 WTI NR7 compression."
    quality_tier: A
    role: primary
sources:
  - "[[sources/CRABEL-WTI-NR7-BRK-2026]]"
concepts:
  - "[[concepts/narrow-range-breakout]]"
  - "[[concepts/volatility-compression-expansion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [nr7, narrow-range-breakout, volatility-compression, trend-filter-ma, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13096_XTI_NR7_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI NR7 compression breakout; estimate 8-20 trades/year after NR7, trend, close-location, spread, and one-entry-per-week filters."
expected_trades_per_year_per_symbol: 12
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
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS Crabel price-pattern source; R2 PASS deterministic D1 NR7 compression breakout with SMA trend confirmation, ATR stop/target, trend and max-hold exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI NR7 Compression Breakout

## Hypothesis

Crabel's short-term price-pattern lineage treats narrow-range bars as structural
compression points that can precede range expansion. This card ports that idea
to a low-frequency WTI sleeve: after a completed D1 bar prints the narrowest
range of the last seven completed D1 bars, the next completed D1 bar must close
beyond that NR7 bar in the direction of the broader SMA trend before the EA
enters.

This is intended to add solo crude-oil exposure to the current XAU/SP500/NDX/XNG
book without adding another gold, index, or XNG RSI-like sleeve.

## Source

- Source: [[sources/CRABEL-WTI-NR7-BRK-2026]]
- Primary citation: Crabel, Toby. *Day Trading with Short-Term Price Patterns
  and Opening Range Breakout*. Traders Press, 1990.

No source performance claim is imported. The source provides price-pattern
lineage only; Q02 validates the deterministic Darwinex implementation.

## Concept

The strategy uses only Darwinex `XTIUSD.DWX` OHLC, spread, ATR, SMA, broker
calendar, and V5 framework state. It does not read a futures curve, inventory
feed, WPSR, OPEC release, refinery statistic, hurricane feed, rig count, CFTC
data, EIA data, CME data, volume, open interest, CSV, API, analyst forecast, or
discretionary runtime data.

This is deliberately different from:

- `QM5_12965_wti-week-orb`: weekly opening-range breakout from the first D1 bars
  of the current broker week.
- `QM5_12810_wti-month-orb`: monthly opening-range breakout.
- `QM5_13075_xti-inweek-brk`: completed inside-week compression breakout.
- `QM5_13095_xti-outweek-fade`: completed outside-week exhaustion fade.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, IEA, STEO, SPR, expiry,
  ETF-roll, driving-season, weekday/month, COT, import/export, production,
  distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold, oil/silver, XAU/XAG, XNG,
  and `QM5_12567_cum-rsi2-commodity`: no event data, ratio, season map,
  storage, futures curve, RSI, or basket logic is used.

## Target Symbols And Period

- Target symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: 8-20 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

The EA is a symmetric D1 NR7 breakout. It uses the second-most-recent completed
D1 bar as the setup bar and requires that bar's high-low range to be the
narrowest range among the last seven completed D1 bars ending at the setup. The
most recent completed D1 bar is the confirmation bar. A trade is opened only if
the confirmation close breaks beyond the setup high or low with an ATR buffer,
confirms in the same candle direction, closes in the expected part of its range,
and agrees with the SMA trend and SMA slope.

## Entry

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Setup bar: the D1 bar one bar before the latest completed D1 bar.
- The setup bar must be NR7: its high-low range is strictly narrower than each
  of the six completed D1 bars before it.
- Require the setup range to be between
  `strategy_min_nr_range_atr * ATR(strategy_atr_period)` and
  `strategy_max_nr_range_atr * ATR(strategy_atr_period)`.
- The confirmation bar's broker day-of-week must be between
  `strategy_confirmation_min_dow` and `strategy_confirmation_max_dow`, default
  Tuesday through Thursday.
- Entry Long: confirmation close is above setup high plus
  `strategy_break_buffer_atr * ATR`, confirmation close is above confirmation
  open, confirmation close-location is at least
  `strategy_min_break_close_location`, confirmation close is above
  SMA(`strategy_trend_period`), and the SMA is above its
  `strategy_slope_lag_days` prior value.
- Entry Short: confirmation close is below setup low minus
  `strategy_break_buffer_atr * ATR`, confirmation close is below confirmation
  open, confirmation close-location is no more than
  `1 - strategy_min_break_close_location`, confirmation close is below
  SMA(`strategy_trend_period`), and the SMA is below its
  `strategy_slope_lag_days` prior value.
- Allow at most one entry per broker week.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit

- Exit Long if a completed D1 close falls below SMA(`strategy_trend_period`).
- Exit Short if a completed D1 close rises above SMA(`strategy_trend_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Framework Friday close remains enabled.

## Stop

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- No pyramiding, no gridding, no martingale, no partial close, and no trailing
  stop in v1.

## Parameters To Test

- name: strategy_nr_lookback
  default: 7
  sweep_range: [5, 7, 9]
- name: strategy_confirmation_min_dow
  default: 2
  sweep_range: [1, 2]
- name: strategy_confirmation_max_dow
  default: 4
  sweep_range: [3, 4]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_slope_lag_days
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_min_nr_range_atr
  default: 0.20
  sweep_range: [0.15, 0.20, 0.30]
- name: strategy_max_nr_range_atr
  default: 1.20
  sweep_range: [0.90, 1.20, 1.60]
- name: strategy_break_buffer_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.18]
- name: strategy_min_break_close_location
  default: 0.62
  sweep_range: [0.58, 0.62, 0.70]
- name: strategy_atr_sl_mult
  default: 2.40
  sweep_range: [1.80, 2.40, 3.00]
- name: strategy_atr_tp_mult
  default: 3.00
  sweep_range: [2.20, 3.00, 3.80]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [7, 12, 18]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 8-20 trades/year.
- risk_class: medium-high for crude-oil overnight and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Crabel trading book lineage.
- [x] R2 mechanical: fixed D1 NR7 definition, SMA trend/slope confirmation,
  close-location confirmation, ATR stop/target, SMA trend exit, and max-hold
  exit.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, and
  one position per magic.
- [x] Non-duplicate: WTI NR7 daily compression breakout is not weekly ORB,
  month ORB, inside-week breakout, outside-week fade, event-window WTI,
  calendar WTI, ratio basket, XNG, XAU/XAG, or RSI commodity logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, and confirmation-day guard.
- trade_entry: D1 NR7 compression breakout with ATR buffer, SMA trend/slope
  context, close-location confirmation, and one-entry-per-week guard.
- trade_management: SMA trend-failure exit, ATR target/stop, and max-hold
  stale-position exit.
- trade_close: hard ATR stop/target plus deterministic close rules.

## Falsification

Reject if Q02 produces zero trades, PF below the Q02 floor, drawdown above the
Q02 ceiling, or evidence that the rule is materially correlated with the current
index/metal/XNG live book rather than adding crude-oil sleeve diversity.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial structural WTI NR7 compression breakout build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
