---
ea_id: QM5_13077
slug: xti-prod-fade
type: strategy
strategy_id: EIA-XTI-FIELDPROD-FADE-2026
source_id: EIA-XTI-FIELDPROD-FADE-2026
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
sources:
  - "[[sources/EIA-XTI-FIELDPROD-FADE-2026]]"
concepts:
  - "[[concepts/weekly-crude-field-production]]"
  - "[[concepts/supply-capacity-release-window]]"
  - "[[concepts/failed-breakout-fade]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
strategy_type_flags: [official-release-window, failed-breakout-fade, mean-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13077_XTI_PROD_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly EIA field-production release-window failed-probe fade; roughly 3-8 entries/year after WPSR weekday, channel-probe/reclaim, SMA-stretch, tail, ATR, spread, and one-position filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.06
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, crude_oil_volatility, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed commodity/energy sleeve 2026-07-09: R1 PASS official EIA weekly U.S. field-production series plus WPSR cadence; R2 PASS deterministic D1 Wednesday/Thursday release-window failed channel-probe/reclaim fade with SMA stretch, ATR range/tail filters, ATR stop/target, mean/channel/time exits, and one-position guard; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this fades failed field-production-window probes, whereas QM5_13028 follows confirmed breakouts after compression."
---

# XTI Field-Production Failed-Probe Fade

## Hypothesis

EIA weekly U.S. crude field-production estimates are part of the official
petroleum information cycle. This card does not forecast production values. It
tests whether `XTIUSD.DWX` D1 bars around the WPSR proxy window sometimes probe
beyond a medium crude channel, fail to hold the break, and mean-revert toward a
slow SMA.

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
rule uses only Darwinex D1 OHLC, spread, broker calendar, ATR, SMA, and V5
framework state.

This is deliberately different from `QM5_13028_xti-prod-brk`: that EA requires
pre-window compression and a close-confirmed Donchian breakout in the SMA slope
direction. This card requires a channel probe that is rejected back inside the
prior channel and then fades the move. It is also not WPSR inventory
momentum/fade/inside-bar/pre-event logic, DPR/PSM, import/export, PADD/Cushing,
SPR, refinery, hurricane, OPEC/IEA/STEO/JODI, COT, rig-count, roll/expiry,
weekday/month seasonality, oil-gas, oil-metal, XNG, metals, index, or RSI
commodity logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: approximately 3-8 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, broker calendar, ATR, SMA, and V5
  framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The signal bar must be Wednesday or Thursday in broker calendar.
- Compute ATR and SMA on completed D1 bars.
- Compute the prior channel over `strategy_context_channel` bars, excluding the
  signal bar.
- Long fade: the signal low probes below the prior channel low by at least
  `strategy_min_probe_atr * ATR`, the close reclaims above that channel low,
  the bar has a lower rejection tail, and the low is stretched below the SMA by
  at least `strategy_min_sma_stretch_atr * ATR`.
- Short fade: the signal high probes above the prior channel high by at least
  `strategy_min_probe_atr * ATR`, the close reclaims below that channel high,
  the bar has an upper rejection tail, and the high is stretched above the SMA
  by at least `strategy_min_sma_stretch_atr * ATR`.
- Require the signal range to be at least `strategy_min_signal_range_atr * ATR`.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close a long when the latest completed D1 close reaches or exceeds the SMA,
  or fails back below the prior exit-channel low.
- Close a short when the latest completed D1 close reaches or falls below the
  SMA, or fails back above the prior exit-channel high.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, SMA, channel state, spread, entry price, or
  stop/target prices are unavailable.
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
- name: strategy_context_channel
  default: 34
  sweep_range: [21, 34, 55]
- name: strategy_exit_channel
  default: 13
  sweep_range: [8, 13, 21]
- name: strategy_trend_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_probe_atr
  default: 0.18
  sweep_range: [0.10, 0.18, 0.30]
- name: strategy_min_signal_range_atr
  default: 0.75
  sweep_range: [0.55, 0.75, 1.00]
- name: strategy_min_tail_ratio
  default: 0.28
  sweep_range: [0.20, 0.28, 0.40]
- name: strategy_min_sma_stretch_atr
  default: 0.25
  sweep_range: [0.10, 0.25, 0.45]
- name: strategy_atr_sl_mult
  default: 2.50
  sweep_range: [2.00, 2.50, 3.25]
- name: strategy_atr_tp_mult
  default: 2.25
  sweep_range: [1.75, 2.25, 3.00]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [4, 6, 9]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The EIA source establishes a recurring official weekly U.S. crude field
production series and WPSR cadence. This card imports no source performance
claim. Q02 and later phases must validate or reject the mechanical
`XTIUSD.DWX` realization on Darwinex bars.

## Risk

- expected_pf: 1.06.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-8 entries/year.
- risk_class: medium-high because crude gaps and sparse release-window samples
  require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA weekly U.S. field-production series and
  WPSR release cadence.
- [x] R2 mechanical: fixed WPSR proxy weekdays, D1 channel probe/reclaim, SMA
  stretch, ATR range/tail filters, ATR stop/target, and deterministic
  mean/channel/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: field-production failed-probe fade, not existing
  field-production breakout, WPSR inventory sleeves, SPR, Cushing, DPR, PSM,
  import/export, STEO, COT, refinery, hurricane, OPEC/IEA, rig-count, roll,
  expiry, seasonality, ratio, XNG, metals, index, or commodity RSI logic.

## Framework Alignment

- no_trade: XTI/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid-data checks.
- trade_entry: EIA field-production release-window failed-probe fade with SMA
  stretch, tail, and channel-reclaim confirmation.
- trade_management: max-hold, SMA mean-reach exit, and adverse channel-failure
  exits.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

- 2026-07-09: Mission-directed card created and assigned `QM5_13077`.
- 2026-07-09: Q01 spec validation PASS; `build_check` PASS with 0 warnings;
  strict compile PASS.
- 2026-07-09: Q02 baseline screening enqueued for `XTIUSD.DWX` as work item
  `419d5653-7116-45dd-8422-2d0ace83f3da`.

## Pipeline Phase Status

- G0: APPROVED.
- Q01 build/spec: PASS in `framework/EAs/QM5_13077_xti-prod-fade`.
- Q02 backtest enqueue: PENDING work item
  `419d5653-7116-45dd-8422-2d0ace83f3da` on `XTIUSD.DWX`.
