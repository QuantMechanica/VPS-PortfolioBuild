---
ea_id: QM5_12869
slug: wti-ref-ramp-pb
type: strategy
strategy_id: EIA-WTI-REFINERY-MAINT-2026_S03
source_id: EIA-WTI-REFINERY-MAINT-2026
source_citation: "U.S. Energy Information Administration. Refinery outages: planned and unplanned outages, 2007-2011; U.S. refinery utilization rates slightly higher than last year heading into summer. URLs https://www.eia.gov/petroleum/articles/refoutagesindex.php and https://www.eia.gov/todayinenergy/detail.php?id=61543"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Refinery outages: planned and unplanned outages, 2007-2011."
    location: "https://www.eia.gov/petroleum/articles/refoutagesindex.php"
    quality_tier: A
    role: primary
  - type: government_energy_analysis
    citation: "U.S. Energy Information Administration. U.S. refinery utilization rates slightly higher than last year heading into summer."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=61543"
    quality_tier: A
    role: structural_context
sources:
  - "[[sources/EIA-WTI-REFINERY-MAINT-2026]]"
concepts:
  - "[[concepts/refinery-utilization-ramp]]"
  - "[[concepts/seasonal-pullback]]"
  - "[[concepts/pullback-continuation]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, pullback-continuation, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12869_XTI_REF_RAMP_PB_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency May-July WTI refinery-utilization ramp pullback continuation; estimate 4-9 trades/year before Q02 validates history and fills."
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
hard_rules_at_risk: [symbol_history_sufficiency, low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS official EIA refinery outage/utilization source packet; R2 PASS deterministic May-July D1 pullback-continuation rule with rising SMA trend gate, ATR-normalized pullback depth, short rebound trigger, ATR hard stop, and time/window/trend exits; R3 PASS XTIUSD.DWX is in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# WTI Refinery Ramp Pullback Continuation

## Source

- Source: [[sources/EIA-WTI-REFINERY-MAINT-2026]]
- Primary citation: U.S. Energy Information Administration, "Refinery outages:
  planned and unplanned outages, 2007-2011", URL
  https://www.eia.gov/petroleum/articles/refoutagesindex.php.
- Structural supplement: U.S. Energy Information Administration, "U.S. refinery
  utilization rates slightly higher than last year heading into summer", URL
  https://www.eia.gov/todayinenergy/detail.php?id=61543.

## Concept

EIA documents refinery outage behavior and the transition from maintenance
season into higher utilization heading into summer. This card does not forecast
refinery utilization or import outage data. It expresses that structural regime
as a low-frequency WTI D1 pullback-continuation rule during the May-July
refinery-utilization ramp: buy only after price remains in a rising slow trend,
pulls back from a recent high by an ATR-normalized amount, and then closes back
through a short rebound range.

This is deliberately different from:

- `QM5_12593_eia-wti-ref-fade`: two-sided shoulder-month stretch rejection
  fade. This card is May-July, long-only, and continuation after a measured
  pullback.
- `QM5_12763_wti-ref-sqz-brk`: pre-summer squeeze breakout after ATR
  compression. This card does not require ATR compression or a long Donchian
  breakout; it requires pullback depth from a recent high and a short rebound
  trigger.
- `QM5_12809_eia-jetfuel-brk` and `QM5_12822_eia-jetfuel-pb`: jet-fuel demand
  and refinery-yield sleeves, not the refinery-maintenance/utilization ramp.
- `QM5_12737_eia-wti-drive` and `QM5_12746_eia-wti-drive-pb`: gasoline
  driving-season sleeves, not refinery-utilization ramp logic.
- WTI WPSR, Cushing, hurricane, OPEC, expiry, ETF-roll, weekday/month,
  XTI/XNG, oil/gold, oil/silver, XNG, XAU/XAG, index, and
  `QM5_12567_cum-rsi2-commodity` sleeves: no event surprise, no ratio basket,
  no RSI, no oscillator pullback, no ML, no grid, no martingale.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected frequency: about 4-9 entries/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only. No EIA feed, refinery utilization series, outage feed,
  product-spread feed, futures curve, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior completed D1 bar must fall inside the May 1 through July 31
  refinery-utilization ramp window.
- Host chart must be `XTIUSD.DWX` on D1 with magic slot 0.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Trend gate: prior close must be above SMA(`strategy_trend_period`) and that
  SMA must be above its value `strategy_sma_slope_shift` bars earlier.
- Pullback gate: recent high over `strategy_pullback_lookback` completed D1
  bars, excluding the signal bar, minus prior close must be at least
  `strategy_min_pullback_atr` ATR and no more than `strategy_max_pullback_atr`
  ATR.
- Rebound trigger: prior close must be above prior open and above the highest
  high of the previous `strategy_rebound_lookback` completed D1 bars, excluding
  the signal bar.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close when the active date leaves the May-July ramp window.
- Close when prior completed D1 close falls below SMA(`strategy_trend_period`).
- Close when prior completed D1 close breaks below the lowest low of the
  previous `strategy_exit_channel` completed D1 bars.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when ATR, SMA, channel OHLC, or spread metadata is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long only.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_start_month
  default: 5
  sweep_range: [5]
- name: strategy_start_day
  default: 1
  sweep_range: [1]
- name: strategy_end_month
  default: 7
  sweep_range: [7]
- name: strategy_end_day
  default: 31
  sweep_range: [15, 31]
- name: strategy_trend_period
  default: 84
  sweep_range: [63, 84, 100]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_pullback_lookback
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_rebound_lookback
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_exit_channel
  default: 12
  sweep_range: [8, 12, 18]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_pullback_atr
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00]
- name: strategy_max_pullback_atr
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 20
  sweep_range: [12, 20, 30]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The EIA source establishes refinery outage/utilization seasonality as structural
lineage only. This card imports no source performance claim. Q02 and later
phases must validate or reject the mechanical rule on Darwinex `XTIUSD.DWX`
bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium-high because crude volatility and low-frequency sample
  size need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA refinery outage/utilization source
  packet.
- [x] R2 mechanical: fixed calendar window, rising SMA trend gate,
  ATR-normalized pullback depth, rebound trigger, ATR hard stop, and
  deterministic window/trend/channel/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe and D1
  history registry.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not refinery fade, refinery squeeze breakout, jet-fuel,
  gasoline driving-season, WPSR, Cushing, hurricane, OPEC, expiry, ETF-roll,
  weekday/month, ratio basket, XNG, XAU/XAG, index, or commodity RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: XTI/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid data checks.
- trade_entry: May-July refinery-ramp D1 pullback continuation.
- trade_management: ramp-window end, trend failure, short-channel failure, and
  max-hold exits.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial WTI refinery-ramp pullback continuation card | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PENDING | `artifacts/qm5_12869_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | PENDING | `D:\QM\strategy_farm\state\farm_state.sqlite` |
