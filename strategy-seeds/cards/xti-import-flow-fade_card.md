---
ea_id: QM5_13026
slug: xti-import-flow-fade
type: strategy
strategy_id: EIA-XTI-IMPORT-FLOW-FADE-2026_S01
source_id: EIA-XTI-IMPORT-FLOW-FADE-2026
source_citation: "U.S. Energy Information Administration crude-oil imports, Petroleum & Other Liquids data, and Weekly Petroleum Status Report pages. URLs https://www.eia.gov/dnav/pet/pet_move_impcus_a2_nus_epc0_im0_mbblpd_a.htm, https://www.eia.gov/petroleum/data.php, and https://www.eia.gov/petroleum/supply/weekly/."
source_citations:
  - type: official_data_series
    citation: "U.S. Energy Information Administration. U.S. Crude Oil Imports."
    location: "https://www.eia.gov/dnav/pet/pet_move_impcus_a2_nus_epc0_im0_mbblpd_a.htm"
    quality_tier: A
    role: primary
  - type: official_data_release_page
    citation: "U.S. Energy Information Administration. Petroleum & Other Liquids - Data."
    location: "https://www.eia.gov/petroleum/data.php"
    quality_tier: A
    role: supplement
  - type: official_weekly_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-XTI-IMPORT-FLOW-FADE-2026]]"
concepts:
  - "[[concepts/monthly-crude-import-flow]]"
  - "[[concepts/post-release-absorption]]"
  - "[[concepts/d1-mean-reversion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
  - "[[indicators/donchian-channel]]"
strategy_type_flags: [calendar-anomaly, official-release-window, mean-reversion, trend-breakout-avoidance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy]
single_symbol_only: true
logical_symbol: QM5_13026_XTI_IMPORT_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly crude-import information absorption fade; about 3-8 entries/year after first-business-days, stretch, channel, spread, and one-position filters."
expected_trades_per_year_per_symbol: 5
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
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-07: R1 PASS official EIA crude-import data series, petroleum data release page, and WPSR import/export table lineage; R2 PASS deterministic first-business-days monthly proxy with ATR/SMA stretch fade, Donchian breakout avoidance, ATR stop/target, and time/SMA exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI Monthly Import-Flow Absorption Fade

## Hypothesis

The EIA publishes recurring U.S. crude-oil import data in its petroleum data
products. Imports are a physical-flow channel for WTI-linked supply, but the
card does not forecast import volumes and does not read EIA data at runtime.

This sleeve tests whether sharp `XTIUSD.DWX` D1 moves in the first broker
business days after the monthly petroleum import data cycle are often
absorption moves rather than durable breakouts. The EA fades only ATR-sized
stretches away from SMA when the signal bar has not broken out of the prior
Donchian channel.

## Source

- Primary official data series: U.S. Energy Information Administration,
  "U.S. Crude Oil Imports." URL
  https://www.eia.gov/dnav/pet/pet_move_impcus_a2_nus_epc0_im0_mbblpd_a.htm.
- Official release catalogue: U.S. Energy Information Administration,
  "Petroleum & Other Liquids - Data." URL
  https://www.eia.gov/petroleum/data.php.
- Weekly import/export lineage: U.S. Energy Information Administration,
  "Weekly Petroleum Status Report." URL
  https://www.eia.gov/petroleum/supply/weekly/.

## Concept

This is a single-symbol crude-oil physical-flow absorption sleeve. The source
lineage is official EIA crude import reporting; the executable rule uses a
fixed broker-calendar proxy and the market's own D1 response. A large first-
business-days upside stretch is sold only if it remains inside the prior D1
channel; a large downside stretch is bought under the mirror condition.

This is deliberately different from:

- `QM5_13001_xti-export-flow-brk`: last-business-days export-flow breakout,
  not first-business-days import-flow fade.
- `QM5_13025_xti-psm-mom`: month-end PSM momentum, not post-cycle absorption.
- `QM5_12988_xti-eia-inventory-momentum` and other WPSR sleeves: this is not a
  weekly Wednesday/Thursday inventory reaction rule.
- `QM5_12992_eia-steo-brk`, OPEC/IEA/MOMR/DPR/SPR/Cushing/refinery/hurricane/
  rig-count/roll/expiry sleeves: different official source family or timing.
- WTI month-of-year, weekday, weekend, month-open ORB, turn-of-month momentum,
  52-week anchor, 6-month reversal, carry, XTI/XNG, oil/gold, oil/silver,
  XAU/XAG, XNG, and `QM5_12567_cum-rsi2-commodity`: no RSI, no basket, no
  static month premium, no generic oscillator pullback, and no external runtime
  feed.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: about 3-8 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The previous completed D1 bar must be in the first
  `strategy_window_business_days` broker business days of its month.
- Compute ATR and SMA on completed D1 bars.
- Require the signal bar range to be at least
  `strategy_min_range_atr * ATR`.
- Require the absolute signal bar body to be at least
  `strategy_min_body_atr * ATR`.
- Short fade: signal bar closes above SMA by at least
  `strategy_min_sma_distance_atr * ATR`, closes above its open, and does not
  close above the prior Donchian high.
- Long fade: signal bar closes below SMA by at least
  `strategy_min_sma_distance_atr * ATR`, closes below its open, and does not
  close below the prior Donchian low.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close early when a long closes back above SMA or a short closes back below
  SMA on the latest completed D1 bar.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip setup formation when ATR, SMA, or Donchian OHLC is unavailable.
- Skip if the business-day count cannot be computed from broker calendar.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_window_business_days
  default: 4
  sweep_range: [3, 4, 5]
- name: strategy_channel_lookback
  default: 30
  sweep_range: [20, 30, 45]
- name: strategy_sma_period
  default: 50
  sweep_range: [34, 50, 80]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.85
  sweep_range: [0.70, 0.85, 1.05]
- name: strategy_min_body_atr
  default: 0.25
  sweep_range: [0.20, 0.25, 0.35]
- name: strategy_min_sma_distance_atr
  default: 0.65
  sweep_range: [0.50, 0.65, 0.85]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_atr_tp_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [4, 6, 8]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. EIA is used only as official source
lineage for the crude-import physical-flow data cycle. Q02 tests whether this
deterministic D1 absorption-fade rule has value on Darwinex `XTIUSD.DWX` bars.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. The strategy is one-position-only, with no grid, martingale,
pyramiding, partial close, adaptive sizing, external data, live manifest,
`T_Live` file, AutoTrading action, or portfolio-gate edit.

## Initial Risk Profile

- expected_pf: 1.07.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-8 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA crude import data, petroleum data
  release catalogue, and WPSR import/export lineage.
- [x] R2 mechanical: fixed monthly business-day proxy, ATR/SMA stretch fade,
  Donchian breakout avoidance, ATR hard stop/target, and deterministic
  time/SMA exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  external runtime data, and one position per magic.
- [x] Non-duplicate: not export-flow breakout, PSM momentum, weekly WPSR,
  STEO, OPEC/IEA/MOMR/DPR/SPR/Cushing/refinery/hurricane/rig-count/roll,
  expiry, WTI month/weekday/weekend, month-open ORB, turn-of-month, XTI/XNG,
  XAU/XAG, oil-metal ratio, XNG, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, and first-business-days monthly proxy.
- trade_entry: D1 import-flow absorption fade with ATR range/body, SMA stretch,
  and Donchian breakout avoidance.
- trade_management: SMA mean-reversion completion and max-hold exits.
- trade_close: hard ATR stop/target plus deterministic time/SMA exits and
  framework Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-07.
- Q01: implemented as `framework/EAs/QM5_13026_xti-import-flow-fade`.
- Q02: queued after compile.
