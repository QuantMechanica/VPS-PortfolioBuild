---
ea_id: QM5_13074
slug: eia-jetfuel-fade
type: strategy
source_id: EIA-JETFUEL-SEASON-2026
source_citation: "U.S. Energy Information Administration, Jet fuel made up a record share of U.S. refinery output in 2024, Today in Energy, March 24, 2025, https://www.eia.gov/todayinenergy/detail.php?id=64786; U.S. jet fuel consumption growth slows after air travel recovers from pandemic slowdown, Today in Energy, August 26, 2025, https://www.eia.gov/todayinenergy/detail.php?id=66004; U.S. jet fuel production rises after prices doubled in March, Today in Energy, June 8, 2026, https://www.eia.gov/todayinenergy/detail.php?id=67764"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration, Jet fuel made up a record share of U.S. refinery output in 2024, Today in Energy, March 24, 2025."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=64786"
    quality_tier: A
    role: primary
  - type: government_energy_research
    citation: "U.S. Energy Information Administration, U.S. jet fuel consumption growth slows after air travel recovers from pandemic slowdown, Today in Energy, August 26, 2025."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=66004"
    quality_tier: A
    role: demand_slowdown_context
  - type: government_energy_research
    citation: "U.S. Energy Information Administration, U.S. jet fuel production rises after prices doubled in March, Today in Energy, June 8, 2026."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67764"
    quality_tier: A
    role: post_spike_margin_context
sources:
  - "[[sources/EIA-JETFUEL-SEASON-2026]]"
concepts:
  - "[[concepts/jet-fuel-refinery-yield]]"
  - "[[concepts/jet-fuel-demand-slowdown]]"
  - "[[concepts/post-spike-exhaustion]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, failed-rally-fade, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13074_XTI_JETFUEL_FADE_D1
period: D1
expected_trade_frequency: "Late jet-fuel-window D1 WTI failed-rally fade; estimate 3-8 trades/year after trend, rejection, spread, and date filters."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.07
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS official EIA jet-fuel refinery-output, consumption-slowdown, and post-spike production/margin sources; R2 PASS deterministic D1 late-window failed-rally fade with SMA trend gate, ATR stop, channel/date/time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is short-only failed-rally exhaustion, not the existing jet-fuel breakout or pullback-continuation builds."
---

# WTI Jet Fuel Post-Spike Failed-Rally Fade

## Source

- Source: [[sources/EIA-JETFUEL-SEASON-2026]]
- Primary citation: U.S. Energy Information Administration, "Jet fuel made up a
  record share of U.S. refinery output in 2024", Today in Energy, March 24,
  2025, https://www.eia.gov/todayinenergy/detail.php?id=64786.
- Demand-slowdown context: U.S. Energy Information Administration, "U.S. jet
  fuel consumption growth slows after air travel recovers from pandemic
  slowdown", Today in Energy, August 26, 2025,
  https://www.eia.gov/todayinenergy/detail.php?id=66004.
- Post-spike margin context: U.S. Energy Information Administration, "U.S. jet
  fuel production rises after prices doubled in March", Today in Energy, June
  8, 2026, https://www.eia.gov/todayinenergy/detail.php?id=67764.

## Hypothesis

EIA analysis documents jet fuel as a material refinery-yield channel, but the
same source packet also documents slower consumption growth and a 2026
post-spike easing in shortage concerns after refiners increased jet-fuel output.
This card tests a Darwinex-native expression of that exhaustion regime: after
the early/summer jet-fuel impulse, `XTIUSD.DWX` late-window failed rallies are
shorted only when WTI is not in a rising long-term trend.

The EA does not forecast or ingest jet fuel data. It uses only `XTIUSD.DWX` D1
OHLC, broker calendar, spread, SMA, ATR, and V5 framework state.

This is deliberately different from:

- `QM5_12809_eia-jetfuel-brk`: that card buys summer upside Donchian breakouts.
- `QM5_12822_eia-jetfuel-pb`: that card buys controlled summer pullbacks in a
  rising trend.
- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative oscillator, or broad
  commodity oscillator logic.
- RBOB/gasoline, distillate-winter, WPSR, Cushing, refinery-maintenance,
  hurricane, OPEC, expiry-roll, weekday, month-premium, oil-ratio, XNG, XAU/XAG,
  and long-horizon momentum sleeves already in the registry.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 3-8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker calendar, broker spread, ATR, and
  SMA only. No futures curve, EIA feed, refinery feed, airline feed, inventory
  feed, CSV, API, analyst forecast, or ML model.

## Rules

Entry rules:

- Evaluate only on a new D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- Prior completed D1 bar date must be within August 15 through October 31.
- Prior completed D1 high must tag or exceed the highest high of the prior
  `strategy_rejection_channel` completed D1 bars, excluding the signal bar.
- The signal candle must close in the lower part of its range, below its open,
  and below SMA(`strategy_trend_period`).
- SMA(`strategy_trend_period`) must be flat/down versus
  `strategy_sma_slope_shift` bars earlier.
- Entry direction is short only: SELL `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

Exit rules:

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close if the prior completed D1 date leaves the August 15 through October 31
  fade window.
- Close if the prior completed D1 close rises back above the trend SMA.
- Close on a downside take-profit when close breaks below the lowest low of the
  prior `strategy_exit_channel` completed D1 bars.
- Also close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_start_month
  default: 8
  sweep_range: [8]
- name: strategy_start_day
  default: 15
  sweep_range: [1, 15]
- name: strategy_end_month
  default: 10
  sweep_range: [9, 10]
- name: strategy_end_day
  default: 31
  sweep_range: [15, 31]
- name: strategy_rejection_channel
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_exit_channel
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_trend_period
  default: 100
  sweep_range: [63, 100, 150]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 20]
- name: strategy_max_close_location
  default: 0.40
  sweep_range: [0.30, 0.40, 0.50]
- name: strategy_min_rejection_atr
  default: 0.35
  sweep_range: [0.20, 0.35, 0.55]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 18
  sweep_range: [10, 18, 30]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source packet is used for structural lineage around jet fuel demand,
refinery yields, margin response, and post-spike easing. No EIA time series or
source performance number is imported into QM. Q02 and later phases must
validate whether the deterministic price-only failed-rally fade has edge on
Darwinex `XTIUSD.DWX` bars.

## Risk

- expected_pf: 1.07.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 3-8 trades/year.
- risk_class: medium-high for crude-oil volatility and short-side gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA energy analysis with dated public URLs.
- [x] R2 mechanical: fixed late-window calendar, D1 failed-rally rejection, SMA
  trend gate, ATR stop, and deterministic channel/date/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, and
  one position per magic.
- [x] Non-duplicate: short-only jet-fuel/post-spike failed-rally fade, not the
  existing jet-fuel breakout or pullback-continuation builds.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: August 15-October 31 SMA-gated D1 failed-rally rejection short.
- trade_management: seasonal-window, trend, channel, and max-hold exits.
- trade_close: hard ATR stop plus deterministic exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial structural WTI jet-fuel failed-rally fade card | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PASS | `artifacts/qm5_13074_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | QUEUED | `artifacts/qm5_13074_q02_enqueue_20260709.json` (`d9753f99-47ed-4e88-bc10-5bfa8ced88fc`) |
