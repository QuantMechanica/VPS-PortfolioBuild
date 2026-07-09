---
ea_id: QM5_13088
slug: xti-export-fade
type: strategy
strategy_id: EIA-XTI-EXPORT-FLOW-2026_S02
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
  - "[[sources/EIA-XTI-EXPORT-FLOW-2026]]"
concepts:
  - "[[concepts/u-s-crude-export-flow]]"
  - "[[concepts/month-end-physical-flow-window]]"
  - "[[concepts/failed-breakout-fade]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [official-flow-window, failed-breakout-fade, mean-reversion, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency, energy]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy]
single_symbol_only: true
logical_symbol: QM5_13088_XTI_EXPORT_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI last-business-days export-flow failed-probe fade; estimate 4-9 entries/year after month-end, channel-probe, ATR/SMA stretch, tail, spread, and one-position filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed commodity/energy sleeve 2026-07-09: R1 PASS single EIA export-flow source packet; R2 PASS deterministic D1 last-business-days failed channel-probe fade with ATR/SMA stretch, tail rejection, ATR stop/target, SMA/channel/time exits, and one-position guard; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this fades rejected export-window probes, not QM5_13001 export-flow breakout, QM5_13026 import-flow fade, QM5_13045 net-import fade, WPSR/storage/product/PADD/refinery/OPEC/IEA/JODI/roll/month/weekday/carry/XTI-XNG/oil-metal/commodity-RSI logic."
---

# XTI Export-Flow Failed-Probe Fade

## Source

- Source: [[sources/EIA-XTI-EXPORT-FLOW-2026]]
- Primary official source: U.S. Energy Information Administration, "U.S. crude
  oil exports reached a new record in 2024", Today in Energy, 2025-04-10, URL
  https://www.eia.gov/todayinenergy/detail.php?id=64964.
- Data-cycle support: U.S. Energy Information Administration, "Petroleum &
  Other Liquids - Data", imports/exports and exports-by-destination release
  table, URL https://www.eia.gov/petroleum/data.php.
- Weekly cadence support: U.S. Energy Information Administration, "Weekly
  Petroleum Status Report Schedule", URL
  https://www.eia.gov/petroleum/supply/weekly/schedule.php.

## Concept

EIA documents U.S. crude exports as a large physical-flow channel for
WTI-linked crude and maintains recurring imports/exports publication tables.
This card does not read export data, vessel data, monthly tables, WPSR CSVs,
forecasts, or APIs at runtime. It uses the official export-flow lineage only to
define a low-frequency month-end information/physical-flow window, then trades
only when Darwinex `XTIUSD.DWX` rejects a channel break during that window.

The mechanical expression is symmetric. During the last
`strategy_window_business_days` business days of a broker month, the EA fades a
failed upside channel probe with a short and a failed downside channel probe
with a long. The hypothesis is absorption/rejection after an export-window
price probe, not trend-following continuation.

## Non-Duplicate Rationale

- Not `QM5_13001_xti-export-flow-brk`: that EA follows confirmed channel
  breakouts in the same source family. This card explicitly requires a failed
  probe back inside the channel and trades the opposite direction.
- Not `QM5_13026_xti-import-flow-fade`: this uses last-business-days export
  flow lineage, not first-business-days import-flow absorption.
- Not `QM5_13045_xti-netimp-fade`: this does not compress import/export balance
  into a net-import pressure proxy.
- Not WPSR, Cushing, PADD, distillate, residual fuel, gasoline, jet fuel,
  propane, production, supply, days-of-supply, refinery, hurricane, OPEC, IEA,
  JODI, STEO, DPR, rig-count, roll, expiry, weekday, month, weekend, carry,
  52-week anchor, XTI/XNG, WTI/Brent, oil/gold, oil/silver, XAU/XAG, XNG, or
  `QM5_12567_cum-rsi2-commodity` logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 4-9 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, broker calendar, ATR, SMA, and
  V5 framework state only. No external data feed, CSV, API, monthly export
  table, WPSR file, vessel data, futures curve, analyst forecast, or ML model is
  read at runtime.

## Entry Rules

- Evaluate only on a new D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- The prior completed D1 bar must fall in the last
  `strategy_window_business_days` business days of its broker-calendar month.
- Compute ATR(`strategy_atr_period`) and SMA(`strategy_sma_period`) on the prior
  completed D1 bar.
- Compute the highest high and lowest low of the prior
  `strategy_channel_lookback` completed D1 bars, excluding the signal bar.
- Require signal-bar range of at least `strategy_min_signal_range_atr * ATR`.
- Short fade:
  - signal high probes above prior channel high by at least
    `strategy_min_probe_atr * ATR`,
  - signal close returns below the prior channel high and remains inside the
    channel,
  - upper tail is at least `strategy_min_tail_ratio` of the signal range,
  - signal high is at least `strategy_min_sma_stretch_atr * ATR` above SMA.
- Long fade:
  - signal low probes below prior channel low by at least
    `strategy_min_probe_atr * ATR`,
  - signal close returns above the prior channel low and remains inside the
    channel,
  - lower tail is at least `strategy_min_tail_ratio` of the signal range,
  - signal low is at least `strategy_min_sma_stretch_atr * ATR` below SMA.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close a long if prior D1 close reaches or exceeds SMA(`strategy_sma_period`)
  or breaks below the `strategy_exit_channel` low.
- Close a short if prior D1 close reaches or falls below SMA(`strategy_sma_period`)
  or breaks above the `strategy_exit_channel` high.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_window_business_days
  default: 4
  sweep_range: [3, 4, 5]
- name: strategy_channel_lookback
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_exit_channel
  default: 21
  sweep_range: [13, 21, 34]
- name: strategy_sma_period
  default: 80
  sweep_range: [50, 80, 100]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_probe_atr
  default: 0.18
  sweep_range: [0.12, 0.18, 0.30]
- name: strategy_min_signal_range_atr
  default: 0.70
  sweep_range: [0.55, 0.70, 0.90]
- name: strategy_min_tail_ratio
  default: 0.25
  sweep_range: [0.20, 0.25, 0.35]
- name: strategy_min_sma_stretch_atr
  default: 0.45
  sweep_range: [0.30, 0.45, 0.65]
- name: strategy_atr_sl_mult
  default: 2.50
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_atr_tp_mult
  default: 2.00
  sweep_range: [1.5, 2.0, 2.5]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [4, 7, 10]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. EIA is used only as official source
lineage for the crude-export physical-flow data cycle. Q02 tests whether this
deterministic D1 failed-probe fade has value on Darwinex `XTIUSD.DWX` bars.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. The strategy is one-position-only, with no grid, martingale,
pyramiding, partial close, adaptive sizing, external data, live manifest,
`T_Live` file, AutoTrading action, or portfolio-gate edit.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 4-9 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single EIA crude export-flow source packet.
- [x] R2 mechanical: fixed month-end business-day proxy, failed channel-probe
  fade, ATR/SMA stretch, tail rejection, ATR hard stop/target, and deterministic
  time/SMA/channel exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  external runtime data, and one position per magic.
- [x] Non-duplicate: export-window failed-probe fade, not export-flow breakout,
  import-flow fade, net-import fade, weekly WPSR/inventory, SPR, Cushing, PADD,
  refinery, product-stock, hurricane, roll, expiry, OPEC, IEA, JODI, STEO, DPR,
  rig-count, WTI/Brent, XTI/XNG, oil-metal ratio, month-open ORB,
  turn-of-month, carry, 52-week anchor, RSI, XNG, or XAU/XAG logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and last-business-days month-end window.
- trade_entry: export-flow failed-probe fade with Donchian channel, ATR range,
  SMA stretch, and rejection-tail confirmation.
- trade_management: SMA mean-reversion completion, exit-channel failure, and
  max-hold exits.
- trade_close: hard ATR stop/target plus deterministic time/SMA/channel exits
  and framework Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-09.
- Q01: implemented as `framework/EAs/QM5_13088_xti-export-fade`.
- Q02: queued after compile.
