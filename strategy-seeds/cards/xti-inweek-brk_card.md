---
ea_id: QM5_13075
slug: xti-inweek-brk
type: strategy
strategy_id: CRABEL-WTI-WEEK-ORB-2026_S02
source_id: CRABEL-WTI-WEEK-ORB-2026
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
source_citations:
  - type: book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Short-term price-pattern and breakout lineage, ported to a D1 WTI inside-week compression breakout."
    quality_tier: A
    role: primary
sources:
  - "[[sources/CRABEL-WTI-WEEK-ORB-2026]]"
concepts:
  - "[[concepts/weekly-range-compression]]"
  - "[[concepts/volatility-expansion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [narrow-range-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13075_XTI_INWEEK_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI inside-week compression breakout; estimate 8-18 trades/year after inside-week, SMA, close-location, range, spread, and one-entry-per-week filters."
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
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS Crabel short-term price-pattern/opening-range breakout source packet; R2 PASS deterministic D1 WTI inside-week compression breakout with ATR/SMA/close-location confirmation, ATR stop/target, failed-breakout and max-hold exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# XTI Inside-Week Compression Breakout

## Hypothesis

Crabel's range-pattern and breakout lineage treats compressed ranges as
structural reference points for later volatility expansion. This card ports
that idea to a low-frequency WTI sleeve: a fully completed broker week must be
inside the prior broker week, and the next week can trade a D1 close beyond the
inside-week high or low.

This is intended to add solo crude-oil exposure to the current
XAU/SP500/NDX/XNG book without adding another gold, index, or XNG RSI-like
sleeve.

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

- `QM5_12965_wti-week-orb`: weekly opening-range breakout from the first D1
  bar of the current broker week. This card waits for the entire previous week
  to be inside the week before it, then trades next-week expansion.
- `QM5_12810_wti-month-orb`: monthly first-N-D1-bar opening range. This card is
  week-to-week compression, not a month-open box.
- `QM5_12752_eia-wti-wpsr-idbrk`: post-WPSR inside-bar event breakout. This
  card uses no WPSR/event window and its compression unit is a completed broker
  week.
- WTI weekend-gap fade/bounce cards: this card does not use the weekend gap.
- Fixed WTI weekday/month cards: this card requires range compression and a
  measured breakout, not calendar arrival alone.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll,
  driving-season, distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold,
  oil/silver, XAU/XAG, XNG sleeves, and `QM5_12567_cum-rsi2-commodity`: no
  event data, ratio, storage, futures curve, RSI, or multi-leg basket is used.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 8-18 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Identify the broker week containing the prior completed D1 bar.
- The immediately preceding broker week must be an inside week: its high is at
  or below the high of the week before it, and its low is at or above that prior
  week's low.
- Require both the inside week and parent week to have at least
  `strategy_min_week_bars` completed D1 bars.
- Require the inside-week range to be between
  `strategy_min_inside_range_atr * ATR(strategy_atr_period)` and
  `strategy_max_inside_range_atr * ATR(strategy_atr_period)`.
- Require the parent-week range to be at least
  `strategy_min_parent_range_atr * ATR(strategy_atr_period)`.
- Signal bars are allowed only when the prior completed D1 bar's day-of-week is
  between `strategy_signal_min_dow` and `strategy_signal_max_dow`, default
  Monday through Thursday.
- Entry Long: prior close is above
  `inside_week_high + strategy_entry_buffer_atr * ATR`, above
  SMA(`strategy_trend_period`), and closes in the top
  `strategy_min_close_location` fraction of the D1 range.
- Entry Short: prior close is below
  `inside_week_low - strategy_entry_buffer_atr * ATR`, below
  SMA(`strategy_trend_period`), and closes in the bottom range fraction.
- Allow at most one entry per broker week.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- Exit Long if a completed D1 close falls back below the inside-week high or
  below SMA(`strategy_trend_period`).
- Exit Short if a completed D1 close rises back above the inside-week low or
  above SMA(`strategy_trend_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when ATR, SMA, weekly ranges, close location, or prices are
  unavailable.
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
- name: strategy_min_inside_range_atr
  default: 0.60
  sweep_range: [0.40, 0.60, 0.80]
- name: strategy_max_inside_range_atr
  default: 2.40
  sweep_range: [1.80, 2.40, 3.00]
- name: strategy_min_parent_range_atr
  default: 1.20
  sweep_range: [0.90, 1.20, 1.60]
- name: strategy_entry_buffer_atr
  default: 0.08
  sweep_range: [0.04, 0.08, 0.12]
- name: strategy_min_close_location
  default: 0.58
  sweep_range: [0.55, 0.58, 0.65]
- name: strategy_atr_sl_mult
  default: 2.60
  sweep_range: [2.0, 2.6, 3.2]
- name: strategy_atr_tp_mult
  default: 3.20
  sweep_range: [2.5, 3.2, 4.0]
- name: strategy_max_hold_days
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No source performance claim is imported into QM. The source is used only for
structural lineage around price-pattern breakouts and volatility expansion.
Q02+ must validate this deterministic Darwinex `XTIUSD.DWX` realization.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 8-18 trades/year.
- risk_class: medium-high for crude-oil overnight and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Crabel trading book source.
- [x] R2 mechanical: fixed weekly inside-week definition, ATR/SMA
  confirmation, ATR stop/target, failed-breakout, and max-hold exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: WTI inside-week compression breakout is not WTI weekly ORB,
  monthly ORB, WPSR inside-bar event breakout, weekend gap, fixed
  weekday/month anomaly, event sleeve, broad TSMOM/Donchian, ratio basket, VRP
  proxy, or commodity RSI pullback.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, and signal-day guard.
- trade_entry: inside-week compression breakout with ATR buffer, SMA trend
  confirmation, close-location confirmation, and one-entry-per-week guard.
- trade_management: failed-breakout exit, SMA failure exit, ATR target/stop,
  and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial structural WTI inside-week compression breakout build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
