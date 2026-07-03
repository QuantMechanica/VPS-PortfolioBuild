---
ea_id: QM5_13001
slug: xti-export-flow-brk
type: strategy
strategy_id: EIA-XTI-EXPORT-FLOW-2026
source_id: EIA-XTI-EXPORT-FLOW-2026
source_citation: "U.S. Energy Information Administration, U.S. crude oil exports reached a new record in 2024, Today in Energy, 2025-04-10, https://www.eia.gov/todayinenergy/detail.php?id=64964; EIA Petroleum & Other Liquids Data, imports/exports release table, https://www.eia.gov/petroleum/data.php; EIA WPSR schedule, https://www.eia.gov/petroleum/supply/weekly/schedule.php"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. U.S. crude oil exports reached a new record in 2024. Today in Energy, 2025-04-10."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=64964"
    quality_tier: A
    role: primary
  - type: government_energy_data_catalog
    citation: "U.S. Energy Information Administration. Petroleum & Other Liquids Data, imports/exports and exports-by-destination release table."
    location: "https://www.eia.gov/petroleum/data.php"
    quality_tier: A
    role: supplement
  - type: government_energy_release_schedule
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report Schedule."
    location: "https://www.eia.gov/petroleum/supply/weekly/schedule.php"
    quality_tier: A
    role: supplement
sources:
  - "https://www.eia.gov/todayinenergy/detail.php?id=64964"
  - "https://www.eia.gov/petroleum/data.php"
  - "https://www.eia.gov/petroleum/supply/weekly/schedule.php"
concepts:
  - "u-s-crude-export-flow"
  - "monthly-official-export-data-cycle"
  - "month-end-physical-flow-breakout"
indicators:
  - "Donchian channel"
  - "SMA"
  - "ATR"
strategy_type_flags: [donchian-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13001_XTI_EXPORT_FLOW_BRK_D1
period: D1
expected_trade_frequency: "D1 WTI last-business-days export-flow breakout; estimate 3-8 trades/year after month-end, range/body, trend, channel, spread, and one-position filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.10
expected_dd_pct: 18.0
ml_required: false
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official EIA crude export analysis plus EIA petroleum imports/exports data catalog and WPSR cadence; R2 PASS deterministic D1 last-business-days-of-month Donchian breakout with SMA trend/slope, ATR range/body gate, ATR hard stop, channel/trend/time exits, and one-position guard; R3 PASS XTIUSD.DWX available in the local symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus existing WTI sleeves because this is a monthly export-flow information-window breakout, not weekly WPSR inventory momentum/fade/pre-event/inside-bar, SPR, Cushing, refinery, RBOB, distillate, jet fuel, hurricane, roll, expiry, OPEC, IEA, STEO, DPR, rig-count, WTI/Brent, XTI/XNG, oil-metal ratio, month-open ORB, turn-of-month momentum, carry, 52-week anchor, RSI, or broad commodity trend/reversal logic."
---

# XTI Export Flow Breakout

## Source

- Primary official source: U.S. Energy Information Administration, "U.S. crude
  oil exports reached a new record in 2024", Today in Energy, 2025-04-10,
  URL https://www.eia.gov/todayinenergy/detail.php?id=64964.
- Data-cycle support: U.S. Energy Information Administration, "Petroleum &
  Other Liquids Data", imports/exports and exports-by-destination release
  table, URL https://www.eia.gov/petroleum/data.php.
- Weekly cadence support: U.S. Energy Information Administration, "Weekly
  Petroleum Status Report Schedule", URL
  https://www.eia.gov/petroleum/supply/weekly/schedule.php.

## Concept

EIA documents U.S. crude exports as a large, recurring physical-flow channel
for WTI-linked crude, with exports by destination and weekly import/export data
published in official petroleum data products. This card does not read export
data, vessel data, monthly tables, WPSR CSVs, forecasts, or APIs at runtime.
It uses the official export-flow lineage only to define a low-frequency
month-end information/physical-flow window, then requires Darwinex `XTIUSD.DWX`
to confirm with a medium-term D1 channel breakout and trend slope.

The mechanical expression is symmetric. During the last `strategy_window_business_days`
business days of a broker month, buy a confirmed upside breakout or sell a
confirmed downside breakout. Exits are deterministic: ATR hard stop, opposite
channel failure, trend failure, or max-hold time.

## Non-Duplicate Rationale

- Not `QM5_12988_xti-eia-inventory-momentum`, `QM5_12579_eia-wti-aftershock`,
  `QM5_12590_eia-wti-wpsr-fade`, `QM5_12592_eia-wti-prewpsr`, or
  `QM5_12752_eia-wti-wpsr-idbrk`: this rule is not a weekly WPSR reaction
  strategy and does not inspect Wednesday/Thursday event bars.
- Not `QM5_12998_xti-spr-relief`, Cushing, refinery, RBOB, distillate, jet
  fuel, hurricane, OPEC, IEA OMR, STEO, DPR, rig-count, roll, or expiry logic:
  none of those source families or event windows are used.
- Not `QM5_12810_wti-month-orb` or `QM5_12983_wti-tom-mom`: this is a
  last-business-days export-flow breakout using a 63-D1 channel and slow SMA
  slope, not a month-opening range or turn-of-month drift rule.
- Not XAU/XAG, XTI/XNG, WTI/Brent, oil/gold, oil/silver, carry, 52-week anchor,
  RSI commodity pullback, or broad commodity time-series momentum/reversal.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 3-8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, broker calendar, ATR, and SMA
  only. No external data feed, CSV, API, monthly export table, WPSR file, vessel
  data, futures curve, analyst forecast, or ML model is read at runtime.

## Entry Rules

- Evaluate only on a new D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- The prior completed D1 bar must fall in the last
  `strategy_window_business_days` business days of its broker-calendar month.
- Compute ATR(`strategy_atr_period`) and SMA(`strategy_trend_period`) on the
  prior completed D1 bar.
- Require SMA slope confirmation over `strategy_sma_slope_shift` D1 bars.
- Compute the highest high and lowest low of the prior
  `strategy_entry_channel` completed D1 bars, excluding the signal bar.
- Require the signal bar range to be at least `strategy_min_range_atr` times ATR.
- Require the signal bar body to be at least `strategy_min_body_ratio` of range.
- Long setup:
  - Signal close is above the prior channel high.
  - Signal close is above SMA(`strategy_trend_period`).
  - Current SMA is above the SMA from `strategy_sma_slope_shift` bars earlier.
  - Signal close is above signal open.
- Short setup:
  - Signal close is below the prior channel low.
  - Signal close is below SMA(`strategy_trend_period`).
  - Current SMA is below the SMA from `strategy_sma_slope_shift` bars earlier.
  - Signal close is below signal open.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long if prior D1 close falls below SMA(`strategy_trend_period`) or
  below the prior `strategy_exit_channel` low.
- Close a short if prior D1 close rises above SMA(`strategy_trend_period`) or
  above the prior `strategy_exit_channel` high.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_window_business_days
  default: 4
  sweep_range: [3, 4, 5]
- name: strategy_entry_channel
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_exit_channel
  default: 21
  sweep_range: [13, 21, 34]
- name: strategy_trend_period
  default: 100
  sweep_range: [84, 100, 150]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.60
  sweep_range: [0.45, 0.60, 0.80]
- name: strategy_min_body_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 18
  sweep_range: [10, 18, 28]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Risk

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-8 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA crude export analysis, EIA petroleum
  imports/exports data catalog, and EIA WPSR release schedule.
- [x] R2 mechanical: fixed month-end business-day window, D1 channel breakout,
  SMA trend/slope gate, ATR/body filters, ATR hard stop, and deterministic
  channel/trend/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  external runtime data, and one position per magic.
- [x] Non-duplicate: not weekly WPSR/inventory, SPR, Cushing, refinery, product
  crack, hurricane, roll, expiry, OPEC, IEA, STEO, DPR, rig-count, WTI/Brent,
  XTI/XNG, oil-metal ratio, month-open ORB, turn-of-month momentum, carry,
  52-week anchor, RSI, XNG, or XAU/XAG logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and last-business-days month-end window.
- trade_entry: month-end export-flow D1 breakout with ATR range/body,
  Donchian channel, SMA trend, and SMA slope confirmation.
- trade_management: trend failure, opposite-channel failure, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/trend/channel exits and
  framework Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-03.
- Q01: implemented as `framework/EAs/QM5_13001_xti-export-flow-brk`.
- Q02: queued after compile.
