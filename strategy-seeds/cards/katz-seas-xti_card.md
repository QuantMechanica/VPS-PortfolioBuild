---
ea_id: QM5_12782
slug: katz-seas-xti
type: strategy
strategy_id: katz-encyclopedia-2000-ch8-xti
source_id: katz-encyclopedia-2000-ch8
source_citation: "Katz, J. O. and McCormick, D. L. The Encyclopedia of Trading Strategies. McGraw-Hill, 2000, Chapter 8, pp. 185-189, Tests 7-9."
source_citations:
  - type: book
    citation: "Katz, J. O. and McCormick, D. L. (2000). The Encyclopedia of Trading Strategies. McGraw-Hill, Ch.8 seasonality crossover-with-confirmation model."
    location: "Local library cache D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt; summarized in docs/research/LIBRARY_MINING_katz-mccormick-encyclopedia-2000_2026-06.md."
    quality_tier: A
    role: primary
sources:
  - "[[sources/katz-encyclopedia-2000-ch8]]"
concepts:
  - "[[concepts/seasonality]]"
  - "[[concepts/adaptive-seasonal-series]]"
  - "[[concepts/stochastic-confirmation]]"
indicators:
  - "[[indicators/seasonal-series]]"
  - "[[indicators/stochastic]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, seasonal-crossover, stochastic-confirmation, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 WTI adaptive seasonal-crossover sleeve; estimate 6-10 stop-entry packages/year after six-year warmup, stochastic confirmation, and framework filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single Tier-A book source already approved for Katz Ch.8; R2 PASS deterministic day-of-year seasonal momentum curve, displaced SMA crossover, stochastic confirmation, stop entry, SES ATR stop/target, and time exit; R3 PASS XTIUSD.DWX is available and crude oil was one of the source's strongest commodity markets; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# Katz Seasonal XTI

## Source

- Primary source: Katz and McCormick, *The Encyclopedia of Trading Strategies*, Chapter 8, seasonality crossover-with-confirmation model.
- Repo evidence: `docs/research/LIBRARY_MINING_katz-mccormick-encyclopedia-2000_2026-06.md` records the Ch.8 extraction and notes that the stronger original market cluster was commodity-driven, including light crude.

## Concept

Katz and McCormick's Ch.8 model builds a day-of-year seasonal momentum curve from prior years, integrates that curve into a seasonal pseudo-price, then trades only when the seasonal pseudo-price crosses a displaced moving average and current price confirms with a Stochastic extreme. This card ports that adaptive seasonal model to `XTIUSD.DWX` so the energy sleeve is not another fixed WTI month, weekday, event, ratio, or RSI rule.

This is deliberately different from:

- WTI fixed calendar sleeves such as `wti-feb-prem`, `wti-mar-prem`, `wti-apr-prem`, `wti-aug-prem`, `wti-oct-fade`, `wti-nov-fade`, `wti-dec-fade`, `wti-febsep-prem`, `wti-wed-prem`, and `wti-thu-prem`: this card does not enter because a fixed day or month arrived.
- WTI structural event sleeves such as WPSR, OPEC, hurricane, refinery, expiry, ETF-roll, SPR, and driving-season builds: this card uses no event date, report timing, or external data.
- WTI trend/reversal sleeves such as Donchian/Turtle, 52-week anchor, TSMOM, Abraham pullback, Williams 8-week box, and Yang/commodity reversal: this card's signal is an adaptive seasonal pseudo-price crossover with Stochastic confirmation.
- Ratio baskets such as XTI/XNG, XAU/XAG, oil/gold, and oil/silver: this is a single-symbol WTI sleeve.
- `QM5_12546_katz-seasonal-crossover-stoch-confirmation-stop-d1`: that build tests XAUUSD/GDAXI proxies. This card is the WTI energy port motivated by the source's commodity-market evidence.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator pullback, ML, grid, martingale, or short-horizon commodity fade logic is used.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker spread, framework Stochastic, and framework ATR only. No futures curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Require at least `strategy_min_years` prior-year samples for the same day-of-year neighborhood before a seasonal value is valid.
- Build the day-of-year seasonal momentum curve from prior-year ATR-normalized one-day movement, capped at `strategy_seasonal_years`.
- Integrate the curve into a seasonal pseudo-price for the current year.
- Compute the displaced SMA of the seasonal pseudo-price using `strategy_seasonal_sma` and `strategy_sma_displacement`.
- Long setup: seasonal pseudo-price crosses above the displaced SMA and Stochastic %K is below `strategy_stoch_long_max`.
- Short setup: seasonal pseudo-price crosses below the displaced SMA and Stochastic %K is above `strategy_stoch_short_min`.
- Entry uses stop confirmation: buy stop one tick above the signal bar high, or sell stop one tick below the signal bar low.
- Stop orders expire after `strategy_stop_valid_bars` D1 bars.
- No entry if an open position or pending stop already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: Katz SES hard stop at ATR(`strategy_exit_atr`) * `strategy_sl_atr_mult`.
- Profit target: ATR(`strategy_exit_atr`) * `strategy_tp_atr_mult`.
- Time exit after `strategy_time_exit_bars` D1 bars.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when seasonal cache, Stochastic, ATR, tick size, point size, or current prices are unavailable.
- Framework news, kill-switch, magic, stress, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short stop-entry packages.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position or pending stop per magic/symbol.

## 8. Parameters To Test

- name: strategy_seasonal_years
  default: 10
  sweep_range: [8, 10, 12]
- name: strategy_min_years
  default: 6
  sweep_range: [6]
- name: strategy_seasonal_sma
  default: 15
  sweep_range: [10, 15, 20]
- name: strategy_sma_displacement
  default: 7
  sweep_range: [5, 7, 9]
- name: strategy_momentum_atr
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_exit_atr
  default: 50
  sweep_range: [40, 50, 60]
- name: strategy_sl_atr_mult
  default: 1.0
  sweep_range: [0.75, 1.0, 1.25]
- name: strategy_tp_atr_mult
  default: 4.0
  sweep_range: [3.0, 4.0, 5.0]
- name: strategy_stoch_k
  default: 5
  sweep_range: [5]
- name: strategy_stoch_d
  default: 3
  sweep_range: [3]
- name: strategy_stoch_slowing
  default: 3
  sweep_range: [3]
- name: strategy_stoch_long_max
  default: 25.0
  sweep_range: [20.0, 25.0, 30.0]
- name: strategy_stoch_short_min
  default: 75.0
  sweep_range: [70.0, 75.0, 80.0]
- name: strategy_stop_valid_bars
  default: 3
  sweep_range: [2, 3, 4]
- name: strategy_time_exit_bars
  default: 10
  sweep_range: [8, 10, 12]
- name: strategy_history_bars
  default: 4500
  sweep_range: [4500]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No source performance number is imported into QM. The source is used only for structural lineage around adaptive commodity seasonality with Stochastic confirmation and the Katz standard exit strategy. Q02+ must validate this deterministic Darwinex `XTIUSD.DWX` realization.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-10 trades/year after warmup.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single approved Katz and McCormick book source.
- [x] R2 mechanical: fixed seasonal-curve construction, fixed displaced SMA crossover, fixed Stochastic confirmation, fixed stop entry, fixed ATR SES exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: adaptive seasonal crossover on WTI, not fixed WTI calendar/event, not trend/reversal, not ratio basket, not RSI commodity pullback, and not the existing XAU/GDAXI Katz port.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` setfile. Live risk is intentionally not configured here; any future live allocation must come from the portfolio process. The EA does not touch `T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread cap.
- trade_entry: adaptive seasonal pseudo-price crossover with Stochastic confirmation and stop-entry confirmation.
- trade_management: static broker SL/TP only.
- trade_close: Katz SES time exit plus framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial WTI energy port of Katz Ch.8 adaptive seasonal crossover | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
