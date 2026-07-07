---
ea_id: QM5_13028
slug: xti-prod-brk
type: strategy
strategy_id: EIA-XTI-FIELDPROD-BRK-2026
source_id: EIA-XTI-FIELDPROD-BRK-2026
source_citation: "U.S. Energy Information Administration weekly U.S. field production of crude oil series and Weekly Petroleum Status Report pages. URLs https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2 and https://www.eia.gov/petroleum/supply/weekly/."
source_citations:
  - type: official_data_series
    citation: "U.S. Energy Information Administration. Weekly U.S. Field Production of Crude Oil."
    location: "https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2"
    quality_tier: A
    role: primary
  - type: official_weekly_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: supplement
  - type: official_release_schedule
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report Schedule."
    location: "https://www.eia.gov/petroleum/supply/weekly/schedule.php"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-XTI-FIELDPROD-BRK-2026]]"
concepts:
  - "[[concepts/weekly-crude-field-production]]"
  - "[[concepts/supply-capacity-release-window]]"
  - "[[concepts/compression-breakout]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/donchian-breakout]]"
  - "[[indicators/sma]]"
strategy_type_flags: [official-release-window, narrow-range-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13028_XTI_PROD_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly EIA field-production release-window compression breakout; roughly 4-9 entries/year after WPSR weekday, compression, trend, channel, range, and spread filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.08
expected_dd_pct: 19.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, crude_oil_volatility, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-07: R1 PASS official EIA weekly U.S. field-production series plus WPSR cadence; R2 PASS deterministic D1 Wednesday/Thursday release-window compression breakout with SMA trend/slope, Donchian channel, ATR stop/target, channel/trend/time exits, and one-position guard; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this is field-production supply-capacity breakout after pre-release compression, not the existing WPSR inventory momentum/fade/inside-bar/pre-event/aftershock, SPR, Cushing, DPR, PSM, import/export, STEO, COT, refinery, hurricane, OPEC/IEA, roll/expiry, rig-count, seasonality, ratio, XNG, XAU/XAG, or RSI commodity logic."
---

# XTI Field-Production Compression Breakout

## Hypothesis

The EIA publishes weekly U.S. crude-oil field-production estimates inside the
official petroleum information cycle. This card does not forecast production
levels and does not read EIA data at runtime. It asks whether `XTIUSD.DWX`
compression ahead of the regular weekly petroleum release can resolve into a
short D1 breakout when the release-window bar also confirms trend direction.

## Source

- Primary official data series: U.S. Energy Information Administration,
  "Weekly U.S. Field Production of Crude Oil." URL
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2.
- Official report cadence: U.S. Energy Information Administration, "Weekly
  Petroleum Status Report." URL https://www.eia.gov/petroleum/supply/weekly/.
- Release schedule: U.S. Energy Information Administration, "Weekly Petroleum
  Status Report Schedule." URL
  https://www.eia.gov/petroleum/supply/weekly/schedule.php.

## Concept

This is a single-symbol crude-oil supply-capacity release-window sleeve. The
source lineage is official EIA weekly field-production reporting; the executable
rule uses only the market's D1 response around the WPSR proxy weekday. A trade
is allowed only after the prior D1 range has compressed versus a multi-bar ATR
baseline, then the release-window bar breaks a medium channel in the same
direction as the slow SMA slope.

This is deliberately different from:

- `QM5_12988_xti-eia-inventory-momentum`: two WPSR inventory-reaction bars plus
  channel confirmation; this card requires pre-release compression and a single
  field-production release-window breakout.
- `QM5_12590_eia-wti-wpsr-fade`, `QM5_12579_eia-wti-aftershock`,
  `QM5_12592_eia-wti-prewpsr`, and `QM5_12752_eia-wti-wpsr-idbrk`: not one-bar
  fade, generic aftershock, pre-event positioning, or post-event inside-bar
  breakout.
- `QM5_12996_xti-dpr-mom` and `QM5_13025_xti-psm-mom`: monthly production or
  supply-disposition windows, not weekly field-production estimates.
- `QM5_13001_xti-export-flow-brk` and `QM5_13026_xti-import-flow-fade`:
  physical-flow import/export timing, not field-production supply capacity.
- SPR, Cushing, refinery, hurricane, OPEC/IEA/MOMR/STEO, COT, rig-count, roll,
  expiry, weekday/month seasonality, WTI/Brent, XTI/XNG, oil-metal, XNG,
  XAU/XAG, broad commodity trend/reversal/carry, and RSI commodity sleeves.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: approximately 4-9 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, broker calendar, ATR, SMA, and V5
  framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The previous completed D1 bar must be a WPSR proxy weekday:
  `strategy_event_dow_1` or `strategy_event_dow_2` in broker calendar.
- Compute ATR and SMA on completed D1 bars.
- Compute the pre-signal compression range over
  `strategy_compression_lookback` completed bars, excluding the signal bar.
- Require that compression range to be no greater than
  `strategy_max_compression_atr * ATR * sqrt(strategy_compression_lookback)`.
- Compute the prior Donchian channel over `strategy_entry_channel` bars,
  excluding the signal bar.
- Require the signal bar range to be at least
  `strategy_min_signal_range_atr * ATR`.
- Require the signal bar body to be at least
  `strategy_min_body_ratio` of the signal range.
- Long entry: signal close is above the prior channel high, above SMA, SMA is
  rising versus `strategy_sma_slope_shift` bars earlier, and signal close is
  above signal open.
- Short entry: signal close is below the prior channel low, below SMA, SMA is
  falling versus `strategy_sma_slope_shift` bars earlier, and signal close is
  below signal open.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close a long if the latest completed D1 close falls below SMA or below the
  prior `strategy_exit_channel` low.
- Close a short if the latest completed D1 close rises above SMA or above the
  prior `strategy_exit_channel` high.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, SMA, channel, compression state, spread,
  entry price, or stop/target prices are unavailable.
- Framework kill-switch, news, magic, risk, stress, and Friday-close guards
  remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_event_dow_1
  default: 3
  sweep_range: [3]
- name: strategy_event_dow_2
  default: 4
  sweep_range: [4]
- name: strategy_compression_lookback
  default: 12
  sweep_range: [8, 12, 16]
- name: strategy_entry_channel
  default: 34
  sweep_range: [21, 34, 55]
- name: strategy_exit_channel
  default: 13
  sweep_range: [8, 13, 21]
- name: strategy_trend_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_sma_slope_shift
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_max_compression_atr
  default: 0.95
  sweep_range: [0.75, 0.95, 1.15]
- name: strategy_min_signal_range_atr
  default: 0.80
  sweep_range: [0.60, 0.80, 1.05]
- name: strategy_min_body_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.50]
- name: strategy_atr_tp_mult
  default: 3.25
  sweep_range: [2.25, 3.25, 4.25]
- name: strategy_max_hold_days
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The EIA source establishes a recurring official weekly U.S. crude field
production series and WPSR cadence. This card imports no source performance
claim. Q02 and later phases must validate or reject the mechanical
`XTIUSD.DWX` realization on Darwinex bars.

## Risk

- expected_pf: 1.08.
- expected_dd_pct: 19.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium-high because crude-oil gaps and sparse release-window
  samples require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA weekly U.S. field-production series and
  WPSR release cadence.
- [x] R2 mechanical: fixed WPSR proxy weekdays, D1 compression, SMA trend/slope,
  Donchian breakout, ATR stop/target, and deterministic channel/trend/time
  exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: field-production compression breakout, not existing
  inventory, SPR, Cushing, DPR, PSM, import/export, STEO, COT, refinery,
  hurricane, OPEC/IEA, rig-count, roll, expiry, seasonality, ratio, XNG,
  metals, or commodity RSI logic.

## Framework Alignment

- no_trade: XTI/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid-data checks.
- trade_entry: EIA field-production release-window compression breakout with
  SMA slope and channel confirmation.
- trade_management: max-hold, SMA trend-failure, and opposite-channel exits.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

- 2026-07-07: Mission-directed card created and assigned `QM5_13028`.
- 2026-07-07: Q01 spec validation PASS; `build_check` PASS with 0 warnings;
  strict compile PASS.
- 2026-07-07: Q02 baseline screening enqueued for `XTIUSD.DWX` as work item
  `b967630d-4229-40dd-89ab-8d6263fbe992`.

## Pipeline Phase Status

- G0: APPROVED.
- Q01 build/spec: PASS in `framework/EAs/QM5_13028_xti-prod-brk`.
- Q02 backtest enqueue: PENDING work item
  `b967630d-4229-40dd-89ab-8d6263fbe992` on `XTIUSD.DWX`.
