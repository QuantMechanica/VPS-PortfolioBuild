---
ea_id: QM5_13035
slug: xti-prod-sup-brk
type: strategy
strategy_id: EIA-XTI-PRODSUP-BRK-2026
source_id: EIA-XTI-PRODSUP-BRK-2026
source_citation: "U.S. Energy Information Administration product supplied proxy and weekly petroleum data pages. URLs https://www.eia.gov/todayinenergy/detail.php?id=63184, https://www.eia.gov/petroleum/data.php, and https://www.eia.gov/dnav/pet/pet_cons_wpsup_k_w.htm."
source_citations:
  - type: official_energy_research
    citation: "U.S. Energy Information Administration. Understanding petroleum product supplied - our proxy for consumption. Today in Energy, 2024-09-19."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=63184"
    quality_tier: A
    role: primary
  - type: official_data_release_page
    citation: "U.S. Energy Information Administration. Petroleum & Other Liquids - Data."
    location: "https://www.eia.gov/petroleum/data.php"
    quality_tier: A
    role: supplement
  - type: official_data_table
    citation: "U.S. Energy Information Administration. U.S. Weekly Product Supplied."
    location: "https://www.eia.gov/dnav/pet/pet_cons_wpsup_k_w.htm"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-XTI-PRODSUP-BRK-2026]]"
concepts:
  - "[[concepts/petroleum-product-supplied-demand-proxy]]"
  - "[[concepts/four-week-demand-trend]]"
  - "[[concepts/d1-demand-window-breakout]]"
indicators:
  - "[[indicators/donchian-breakout]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [official-release-window, structural-demand, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy]
single_symbol_only: true
logical_symbol: QM5_13035_XTI_PRODSUP_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly EIA product-supplied demand proxy breakout with seasonal direction filter; estimate 6-12 entries/year after weekday, channel, SMA-slope, ATR, spread, and one-position filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-07: R1 PASS official EIA product-supplied demand proxy and weekly petroleum data sources; R2 PASS deterministic D1 Wednesday/Thursday proxy bar, seasonal direction map, Donchian breakout, SMA slope, ATR range/body, ATR stop/target, and time/trend exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI Product-Supplied Demand Breakout

## Hypothesis

EIA treats petroleum product supplied as an approximate consumption proxy and
publishes weekly product-supplied data with four-week averages. This card tests
whether `XTIUSD.DWX` breakouts on the weekly product-supplied information
window carry for several D1 bars when the move agrees with the broad demand
season and the four-week price trend.

The EA deliberately does not read EIA data, CSV files, release calendars,
analyst forecasts, or APIs at runtime. The source is used only for structural
lineage. The executable rule uses Darwinex MT5 D1 OHLC, ATR, SMA, spread,
broker calendar, and V5 framework state.

## Source

- Primary: U.S. Energy Information Administration, "Understanding petroleum
  product supplied - our proxy for consumption." URL
  https://www.eia.gov/todayinenergy/detail.php?id=63184.
- Supplement: U.S. Energy Information Administration, "Petroleum & Other
  Liquids - Data." URL https://www.eia.gov/petroleum/data.php.
- Supplement: U.S. Energy Information Administration, "U.S. Weekly Product
  Supplied." URL https://www.eia.gov/dnav/pet/pet_cons_wpsup_k_w.htm.

## Concept

This is a structural crude-oil demand-proxy breakout sleeve. The weekly EIA
product-supplied source family provides the rationale for observing the
Wednesday/Thursday petroleum information window and the four-week trend proxy.
The trading rule is price-only: it enters only when the prior completed D1
proxy bar breaks a Donchian channel in the seasonally aligned direction and the
20-D1 SMA slope agrees.

This is deliberately different from:

- `QM5_12988_xti-eia-inventory-momentum`: two same-direction weekly inventory
  reactions plus breakout; this card uses one product-supplied demand proxy bar,
  a four-week SMA slope, and a seasonal demand direction map.
- `QM5_12752_eia-wti-wpsr-idbrk`: post-event inside-bar breakout; this card
  does not use inside-bar compression.
- `QM5_12579_eia-wti-aftershock`, `QM5_12590_eia-wti-wpsr-fade`, and
  `QM5_12592_eia-wti-prewpsr`: no immediate event aftershock, event fade, or
  pre-event positioning.
- `QM5_13025_xti-psm-mom`, `QM5_13026_xti-import-flow-fade`,
  `QM5_13001_xti-export-flow-brk`, and `QM5_13028_xti-prod-brk`: different
  source cycle, timing, and entry mechanic.
- Month-only WTI cards, COT, OPEC, IEA OMR, STEO, DPR, SPR, Cushing, refinery,
  hurricane, rig-count, roll, expiry, carry, XTI/XNG, WTI/Brent, oil-metal,
  XAU/XAG, XNG, and `QM5_12567_cum-rsi2-commodity`: no static month premium,
  no RSI/oscillator pullback, no basket, and no external runtime feed.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: about 6-12 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and V5
  framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The previous completed D1 bar must be Wednesday or Thursday in broker time.
- Long-demand season is April through August by default.
- Weak-demand season is September through February by default.
- March is neutral by default.
- Compute ATR, SMA, SMA slope, and a Donchian channel on completed D1 bars.
- Require the signal bar range to be at least
  `strategy_min_range_atr * ATR`.
- Require the absolute signal body to be at least
  `strategy_min_body_atr * ATR`.
- Long entry: signal bar is in the long-demand season, closes above its open,
  closes above SMA, SMA is rising, and the close breaks above the prior
  Donchian high.
- Short entry: signal bar is in the weak-demand season, closes below its open,
  closes below SMA, SMA is falling, and the close breaks below the prior
  Donchian low.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close a long if the latest completed D1 close falls below SMA.
- Close a short if the latest completed D1 close rises above SMA.
- Close if the current broker month no longer permits the position direction.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip setup formation when ATR, SMA, Donchian OHLC, spread, entry price, stop,
  or target prices are unavailable.
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

- name: strategy_long_start_month
  default: 4
  sweep_range: [4]
- name: strategy_long_end_month
  default: 8
  sweep_range: [8]
- name: strategy_short_start_month
  default: 9
  sweep_range: [9]
- name: strategy_short_end_month
  default: 2
  sweep_range: [2]
- name: strategy_channel_lookback
  default: 40
  sweep_range: [30, 40, 60]
- name: strategy_sma_period
  default: 20
  sweep_range: [20, 30, 40]
- name: strategy_sma_slope_shift
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.70
  sweep_range: [0.55, 0.70, 0.90]
- name: strategy_min_body_atr
  default: 0.20
  sweep_range: [0.15, 0.20, 0.35]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_atr_tp_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [4, 7, 10]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. EIA is used only as official source
lineage for product-supplied demand proxy data and the four-week trend framing.
Q02 tests whether this deterministic D1 demand-window breakout has value on
Darwinex `XTIUSD.DWX` bars.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. The strategy is one-position-only, with no grid, martingale,
pyramiding, partial close, adaptive sizing, external data, live manifest,
`T_Live` file, AutoTrading action, or portfolio-gate edit.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 6-12 entries/year.
- risk_class: medium-high for crude-oil volatility and low-frequency sample
  risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA product-supplied consumption proxy and
  weekly petroleum data pages.
- [x] R2 mechanical: fixed weekly proxy day, seasonal direction map, Donchian
  breakout, SMA slope, ATR hard stop/target, and deterministic time/SMA/season
  exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  external runtime data, and one position per magic.
- [x] Non-duplicate: not inventory WPSR, PSM, import/export/field-production,
  OPEC/IEA/STEO/DPR/SPR/Cushing/refinery/hurricane/rig-count/roll/expiry,
  month-only, XTI/XNG, oil-metal, XAU/XAG, XNG, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and source-window validation.
- trade_entry: product-supplied proxy D1 breakout with seasonal direction,
  Donchian channel, SMA slope, and ATR/body filters.
- trade_management: SMA failure, seasonal invalidation, and max-hold exits.
- trade_close: hard ATR stop/target plus deterministic exits and framework
  Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-07.
- Q01: PASS on 2026-07-07. Evidence:
  `artifacts/qm5_13035_build_result.json`.
- Q02: ENQUEUED on 2026-07-07. Evidence:
  `artifacts/qm5_13035_q02_enqueue_20260707.json`; work item
  `dabc19c3-f5ce-4c02-bb50-65b97463c6d1`.
