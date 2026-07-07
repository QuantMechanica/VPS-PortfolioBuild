---
ea_id: QM5_13025
slug: xti-psm-mom
type: strategy
strategy_id: EIA-PSM-XTI-MOM-2026_S01
source_id: EIA-PSM-XTI-MOM-2026
source_citation: "U.S. Energy Information Administration. Petroleum Supply Monthly and Petroleum & Other Liquids Data pages. URLs https://www.eia.gov/petroleum/supply/monthly/ and https://www.eia.gov/petroleum/data.php."
source_citations:
  - type: official_report
    citation: "U.S. Energy Information Administration. Petroleum Supply Monthly."
    location: "https://www.eia.gov/petroleum/supply/monthly/"
    quality_tier: A
    role: primary
  - type: official_data_release_page
    citation: "U.S. Energy Information Administration. Petroleum & Other Liquids - Data."
    location: "https://www.eia.gov/petroleum/data.php"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-PSM-XTI-MOM-2026]]"
concepts:
  - "[[concepts/monthly-petroleum-supply-information-window]]"
  - "[[concepts/crude-oil-supply-disposition]]"
  - "[[concepts/d1-event-momentum]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/donchian-breakout]]"
  - "[[indicators/sma]]"
strategy_type_flags: [calendar-anomaly, official-release-window, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy]
single_symbol_only: true
logical_symbol: QM5_13025_XTI_PSM_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA Petroleum Supply Monthly proxy momentum; at most one package per month, roughly 4-8 entries/year after event, range, breakout, trend, and spread filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.07
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-07: R1 PASS official EIA Petroleum Supply Monthly and petroleum data release pages; R2 PASS deterministic D1 month-end PSM proxy window with ATR range/body, Donchian, SMA trend, ATR stop/target, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI PSM Month-End Supply Momentum

## Hypothesis

The EIA Petroleum Supply Monthly is a recurring official U.S. petroleum supply
and disposition publication. This card tests whether an ATR-sized WTI reaction
inside the month-end PSM information window continues for several D1 bars when
confirmed by a trend and breakout filter.

The EA deliberately does not parse EIA data or a release calendar at runtime.
It uses a fixed broker-calendar month-end proxy window so Q02 tests only
Darwinex `XTIUSD.DWX` OHLC behaviour around the monthly petroleum
supply-disposition information cycle.

## Source

- Primary: U.S. Energy Information Administration, "Petroleum Supply Monthly."
  URL: https://www.eia.gov/petroleum/supply/monthly/.
- Supplement: U.S. Energy Information Administration, "Petroleum & Other
  Liquids - Data." URL: https://www.eia.gov/petroleum/data.php.

## Concept

This is a crude-oil supply-disposition information-window sleeve. The source
lineage is official EIA monthly petroleum supply reporting, while the EA uses
only the market's D1 response during a fixed month-end window. A long is taken
only when the prior PSM proxy bar is a large positive range expansion, above
trend, and beyond the prior Donchian high; a short is the mirror case.

This is deliberately different from:

- `QM5_12996_xti-dpr-mom`: mid-month shale-production DPR proxy window.
- `QM5_12992_eia-steo-brk`: early-month STEO release-date breakout.
- `QM5_12988_xti-eia-inventory-momentum`: weekly WPSR inventory reaction.
- OPEC/IEA/MOMR/Cushing/refinery/hurricane/rig-count/roll/expiry sleeves:
  different information source and timing mechanism.
- WTI month-of-year, weekday, weekend, 52-week anchor, 6-month reversal, carry,
  XTI/XNG, oil/gold, oil/silver, XAU/XAG, XNG, and
  `QM5_12567_cum-rsi2-commodity`: no fixed month, no RSI, no basket, no
  oscillator pullback, and no external runtime feed.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: at most one signal per monthly PSM proxy cycle, about
  4-8 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The previous completed D1 bar must be inside the PSM proxy window,
  broker-calendar day `strategy_event_start_day` through
  `strategy_event_end_day` inclusive.
- Compute ATR and SMA on completed D1 bars.
- Require the proxy bar range to be at least
  `strategy_min_range_atr * ATR`.
- Require the absolute proxy bar body to be at least
  `strategy_min_body_atr * ATR`.
- Long entry: proxy bar closes above its open, above SMA, and above the prior
  Donchian high.
- Short entry: proxy bar closes below its open, below SMA, and below the prior
  Donchian low.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close early if a long closes below SMA or a short closes above SMA on the
  latest completed D1 bar.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, SMA, event-window state, spread, entry
  price, or stop/target prices are unavailable.
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

- name: strategy_event_start_day
  default: 28
  sweep_range: [27, 28, 29]
- name: strategy_event_end_day
  default: 31
  sweep_range: [30, 31]
- name: strategy_breakout_lookback
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_trend_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.85
  sweep_range: [0.70, 0.85, 1.05]
- name: strategy_min_body_atr
  default: 0.25
  sweep_range: [0.20, 0.25, 0.40]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_atr_tp_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 7]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source establishes a recurring official monthly petroleum supply and
disposition information cycle. This card imports no source performance claim.
Q02 and later phases must validate or reject the mechanical `XTIUSD.DWX`
realization on Darwinex bars.

## Risk

- expected_pf: 1.07.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 4-8 entries/year.
- risk_class: medium-high because crude-oil gaps and the small monthly sample
  require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA PSM and petroleum data release pages.
- [x] R2 mechanical: fixed month-end event window, D1 range/body, SMA,
  Donchian, ATR stop/target, and deterministic time/trend exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe.
- [x] R4 no banned ML/AI/black-box indicators, no grid, no martingale, no
  external runtime feed.

## Framework Alignment

- V5 modules: no-trade, trade-entry, trade-management, trade-close, news hook.
- Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No portfolio gate file, `T_Live` manifest, or AutoTrading setting is touched
  by this card.

## Pipeline History

- 2026-07-07: Card extracted from official EIA PSM source lineage and assigned
  `QM5_13025` for build.

## Pipeline Phase Status

- G0: APPROVED.
- Q01 build/spec: pending at extraction.
- Q02 backtest enqueue: target phase for the built EA.
