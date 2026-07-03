---
ea_id: QM5_12996
slug: xti-dpr-mom
type: strategy
strategy_id: EIA-DPR-XTI-MOM-2026_S01
source_id: EIA-DPR-XTI-MOM-2026
source_citation: "U.S. Energy Information Administration. Drilling Productivity Report and DPR FAQ. URLs https://www.eia.gov/petroleum/drilling/ and https://www.eia.gov/petroleum/drilling/faqs.php."
source_citations:
  - type: official_report
    citation: "U.S. Energy Information Administration. Drilling Productivity Report."
    location: "https://www.eia.gov/petroleum/drilling/"
    quality_tier: A
    role: primary
  - type: official_faq
    citation: "U.S. Energy Information Administration. Drilling Productivity Report FAQ."
    location: "https://www.eia.gov/petroleum/drilling/faqs.php"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-DPR-XTI-MOM-2026]]"
concepts:
  - "[[concepts/monthly-shale-production-information-window]]"
  - "[[concepts/tight-oil-supply-capacity]]"
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
logical_symbol: QM5_12996_XTI_DPR_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA DPR/shale-production proxy momentum; at most one package per month, roughly 4-9 entries/year after event, range, breakout, trend, and spread filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official EIA DPR and FAQ sources; R2 PASS deterministic D1 mid-month DPR proxy window with ATR range/body, Donchian, SMA trend, ATR stop/target, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI DPR Shale Production Momentum

## Hypothesis

The EIA Drilling Productivity Report was a recurring monthly U.S. shale/tight-oil
information window. EIA describes the DPR as combining rig count, drilling
efficiency, expected new-well yield, and legacy production changes to explain
regional production levels. This card tests whether an ATR-sized WTI reaction
inside the historical mid-month DPR window continues for several D1 bars when
confirmed by a trend and breakout filter.

EIA notes that standalone DPR data moved into STEO data tables after June 11,
2024. This EA deliberately does not parse EIA data or a release calendar at
runtime. It uses a fixed broker-calendar mid-month proxy window so Q02 tests
only Darwinex `XTIUSD.DWX` OHLC behaviour around the shale-production
information cycle.

## Source

- Primary: U.S. Energy Information Administration, "Drilling Productivity
  Report." URL: https://www.eia.gov/petroleum/drilling/.
- Supplement: U.S. Energy Information Administration, "Drilling Productivity
  Report FAQ." URL: https://www.eia.gov/petroleum/drilling/faqs.php.

## Concept

This is a crude-oil supply-capacity information-window sleeve. The DPR source
is specific to U.S. shale/tight-oil regional production mechanics, while the EA
uses only the market's D1 response during a fixed mid-month window. A long is
taken only when the prior DPR proxy bar is a large positive range expansion,
above trend, and beyond the prior Donchian high; a short is the mirror case.

This is deliberately different from:

- `QM5_12992_eia-steo-brk`: STEO release-date breakout around the first Tuesday
  after the first Thursday; this card uses the historical mid-month DPR window.
- `QM5_12988_xti-eia-inventory-momentum`: weekly WPSR reaction momentum, not a
  monthly shale-production window.
- OPEC/IEA/MOMR/STEO/Cushing/refinery/hurricane/rig-count/roll/expiry sleeves:
  different information source and calendar proxy.
- WTI month-of-year, weekday, weekend, 52-week anchor, 6-month reversal, carry,
  XTI/XNG, oil/gold, oil/silver, XAU/XAG, XNG, and
  `QM5_12567_cum-rsi2-commodity`: no fixed month, no RSI, no basket, no
  oscillator pullback, and no external runtime feed.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: at most one signal per monthly DPR proxy cycle, about
  4-9 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The previous completed D1 bar must be inside the DPR proxy window,
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
  default: 12
  sweep_range: [11, 12, 13]
- name: strategy_event_end_day
  default: 16
  sweep_range: [15, 16, 17]
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
  default: 0.90
  sweep_range: [0.75, 0.90, 1.10]
- name: strategy_min_body_atr
  default: 0.30
  sweep_range: [0.25, 0.30, 0.45]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_atr_tp_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [4, 6, 8]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source establishes a monthly official shale/tight-oil production information
cycle and its production-capacity variables. This card imports no source
performance claim. Q02 and later phases must validate or reject the mechanical
`XTIUSD.DWX` realization on Darwinex bars.

## Risk

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium-high because crude-oil gaps and the small monthly sample
  require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA DPR and FAQ sources.
- [x] R2 mechanical: fixed mid-month event window, D1 range/body, SMA,
  Donchian, ATR stop/target, and deterministic time/trend exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: no existing DPR/shale/tight-oil sleeve; not STEO, WPSR,
  OPEC, IEA, Cushing, refinery, rig-count, roll, expiry, month/weekday,
  commodity RSI, XNG, or metals logic.

## Framework Alignment

- no_trade: XTI/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid data checks.
- trade_entry: mid-month DPR proxy event-bar ATR breakout with SMA trend
  confirmation.
- trade_management: max-hold stale-position exit and SMA trend-failure exit.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial WTI DPR shale-production momentum card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
