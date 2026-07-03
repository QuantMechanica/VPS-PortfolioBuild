---
ea_id: QM5_13009
slug: xng-tom-mom
type: strategy
strategy_id: VANHEMERT-MOMTOM-2014_XNG
source_id: VANHEMERT-MOMTOM-2014
source_citation: "Van Hemert, Otto. The MOM-TOM Effect: Detecting the Market Impact of CTA Trading. SSRN, 2014; Moskowitz, Ooi and Pedersen, Time Series Momentum, Journal of Financial Economics, 2012."
source_citations:
  - type: working_paper
    citation: "Van Hemert, Otto. The MOM-TOM Effect: Detecting the Market Impact of CTA Trading. SSRN, 2014."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900"
    quality_tier: A-
    role: primary
  - type: journal_article
    citation: "Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen. Time Series Momentum. Journal of Financial Economics, 104(2), 2012."
    location: "https://docs.lhpedersen.com/TimeSeriesMomentum.pdf"
    quality_tier: A
    role: momentum_lineage
sources:
  - "[[sources/VANHEMERT-MOMTOM-2014]]"
concepts:
  - "[[concepts/turn-of-month]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/cta-flow-price-pressure]]"
indicators:
  - "[[indicators/momentum-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-anomaly, turn-of-month, time-series-momentum, cta-flow, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13009_XNG_TOM_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XNG turn-of-month momentum package; at most one package per month, approximately 5-10 entries/year after momentum, spread, and framework filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-04
expected_pf: 1.08
expected_dd_pct: 24.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-04: R1 PASS Van Hemert SSRN MOM-TOM CTA-flow source plus Moskowitz/Ooi/Pedersen JFE time-series momentum lineage; R2 PASS deterministic D1 turn-of-month calendar window, fixed lookback return sign, ATR hard stop/target, window/time exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus QM5_12567 because this is monthly turn-of-month momentum timing, not short-horizon cumulative RSI pullback."
---

# XNG Turn-Of-Month Momentum

## Hypothesis

Van Hemert's MOM-TOM paper tests whether CTA trend-following flow around the
turn of the month creates temporary price pressure in the direction of existing
momentum. Moskowitz, Ooi and Pedersen document time-series momentum across
futures markets, including commodities. This card ports that structural idea to
Darwinex `XNGUSD.DWX`: during the broker-calendar turn-of-month window, trade
in the direction of a fixed D1 momentum lookback and flatten when the window
ends.

This is intended to add a different natural-gas sleeve to the current
XAU/SP500/NDX/XNG book without creating another index, outright gold,
metals-ratio, WTI event, storage-report, weather, or RSI-pullback alias.

## Source

- Primary: Van Hemert, Otto. "The MOM-TOM Effect: Detecting the Market Impact
  of CTA Trading." SSRN, 2014. URL:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900.
- Momentum lineage: Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen.
  "Time Series Momentum." Journal of Financial Economics, 104(2), 2012. URL:
  https://docs.lhpedersen.com/TimeSeriesMomentum.pdf.

## Concept

The EA uses only Darwinex `XNGUSD.DWX` D1 OHLC, broker-calendar dates, spread,
ATR, and V5 framework state. It does not read CTA holdings, futures curves,
EIA storage data, weather data, rig counts, volume, open interest, CSV,
external APIs, analyst forecasts, or ML output.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon pullback,
  ML, grid, or martingale logic.
- `QM5_12804_xng-tsmom12m-atr`: that EA is long-horizon 12-month trend; this
  card trades only a fixed turn-of-month timing window and uses a 63-D1 default
  momentum lookback.
- `QM5_12812_xng-month-orb`: no monthly opening range, range breakout, or box
  trigger is used.
- XNG storage, storage fade, storage inside-bar breakout, prestorage, freeze,
  hurricane, LNG, rig-count Friday, weekday, weekend-gap, 52-week anchor,
  broad winter/summer/fall/spring seasonality, XNG/AUD, XNG/CAD, gas/gold,
  gas/silver, XBR/XNG, and XTI/XNG baskets: no event feed, report cadence,
  fixed weekday, fixed month-only window, relative-value basket, or medium-term
  overextension fade is used.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: `D1`.
- Expected frequency: at most one entry per broker-calendar turn-of-month
  cycle, about 5-10 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only.

## Entry Rules

- Evaluate only on a new `XNGUSD.DWX` D1 bar.
- The active broker date must be inside the turn-of-month window:
  `strategy_tom_pre_days` calendar days at the end of the current month or
  `strategy_tom_post_days` calendar days at the start of the next month.
- The window is treated as one cycle: first-days-of-month bars belong to the
  previous month-end cycle, so the EA can open at most one package per cycle.
- Compute completed-D1 momentum:
  `return_pct = 100 * (close[1] / close[1 + strategy_momentum_lookback_days] - 1)`.
- Entry Long: `return_pct >= strategy_min_momentum_pct`.
- Entry Short: `return_pct <= -strategy_min_momentum_pct`.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close when the broker date is no longer in the turn-of-month window.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, spread, entry price, or stop/target prices
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

- name: strategy_tom_pre_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_tom_post_days
  default: 3
  sweep_range: [1, 2, 3]
- name: strategy_momentum_lookback_days
  default: 63
  sweep_range: [42, 63, 126]
- name: strategy_min_momentum_pct
  default: 12.0
  sweep_range: [8.0, 12.0, 18.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 3.5]
- name: strategy_atr_tp_mult
  default: 4.0
  sweep_range: [3.0, 4.0, 5.0]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [3, 6, 8]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

The sources establish structural lineage for time-series momentum and a
turn-of-month CTA-flow timing hypothesis. This card imports no source
performance claim. Q02 and later phases must validate or reject the mechanical
`XNGUSD.DWX` realization on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 24.
- expected_trade_frequency: approximately 5-10 entries/year.
- risk_class: high because natural-gas gaps, volatility, and the small monthly
  sample require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Van Hemert SSRN MOM-TOM source and Moskowitz/Ooi/
  Pedersen JFE time-series momentum lineage.
- [x] R2 mechanical: fixed turn-of-month window, fixed return lookback,
  symmetric momentum direction, ATR hard stop/target, and deterministic
  window/time exits.
- [x] R3 testable: `XNGUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not XAU/XAG, not WTI, not XNG RSI, storage, weather,
  rig-count, month-open ORB, weekday/weekend, broad seasonality, 52-week
  anchor, gas/metal, or XTI/XNG logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: XNG/D1 host guard, magic-slot guard, parameter guard, spread cap,
  turn-of-month calendar guard, and valid data checks.
- trade_entry: turn-of-month fixed-lookback D1 momentum direction.
- trade_management: turn-window exit and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-04 | initial XNG turn-of-month momentum card | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-04 | APPROVED | this card |
| Q01 Build | 2026-07-04 | PASS | artifacts/qm5_13009_build_result.json |
| Q02 Enqueue | 2026-07-04 | PENDING | artifacts/qm5_13009_q02_enqueue_20260704.json |
