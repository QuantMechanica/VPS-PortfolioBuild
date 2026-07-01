---
ea_id: QM5_12861
slug: xng-hurr-fade
type: strategy
strategy_id: EIA-NOAA-XNG-HURR-2026_S02
source_id: EIA-NOAA-XNG-HURR-2026
source_citation: "U.S. Energy Information Administration. Forecast strong hurricane season presents risk for U.S. oil and natural gas industry. Today in Energy, 2024-06-13. URL https://www.eia.gov/todayinenergy/detail.php?id=62104; NOAA National Hurricane Center. Tropical Cyclone Climatology. URL https://www.nhc.noaa.gov/climo/"
source_citations:
  - type: government_agency_analysis
    citation: "U.S. Energy Information Administration. Forecast strong hurricane season presents risk for U.S. oil and natural gas industry."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=62104"
    quality_tier: A
    role: primary
  - type: government_weather_reference
    citation: "NOAA National Hurricane Center. Tropical Cyclone Climatology."
    location: "https://www.nhc.noaa.gov/climo/"
    quality_tier: A
    role: structural_context
  - type: government_agency_analysis
    citation: "U.S. Energy Information Administration. Hurricane Ida disrupted crude oil production and refining activity."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=49576"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-NOAA-XNG-HURR-2026]]"
concepts:
  - "[[concepts/natural-gas-hurricane-risk]]"
  - "[[concepts/weather-risk-premium-fade]]"
  - "[[concepts/rejection-candle]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
  - "[[indicators/donchian-channel]]"
strategy_type_flags: [calendar-seasonality, weather-shock-proxy, failed-rally-mean-reversion, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12861_XNG_HURR_FADE_D1
period: D1
expected_trade_frequency: "D1 natural-gas hurricane-window failed-spike fade; estimate 3-7 trades/year after rejection, stretch, channel, spread, and framework filters."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS official EIA hurricane energy-market source plus NOAA/NHC climatology; R2 PASS deterministic XNGUSD.DWX D1 hurricane-window failed-spike fade with ATR/SMA/channel/time exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 25.0
risk_class: high
ml_required: false
---

# XNG Hurricane Failed-Spike Fade

## Source

- Source: [[sources/EIA-NOAA-XNG-HURR-2026]]
- Primary citation: U.S. Energy Information Administration, "Forecast strong hurricane season presents risk for U.S. oil and natural gas industry", Today in Energy, 2024-06-13, URL https://www.eia.gov/todayinenergy/detail.php?id=62104.
- Supplemental citation: NOAA National Hurricane Center, Tropical Cyclone Climatology, URL https://www.nhc.noaa.gov/climo/.
- Supplemental citation: U.S. Energy Information Administration, "Hurricane Ida disrupted crude oil production and refining activity", Today in Energy, 2021-09-14, URL https://www.eia.gov/todayinenergy/detail.php?id=49576.

## Concept

EIA documents that Atlantic hurricanes can disrupt energy markets through Gulf
of Mexico production, LNG export, and infrastructure effects. NOAA/NHC defines
the Atlantic season and peak activity cluster. This card does not forecast
storms or read weather data. It tests whether `XNGUSD.DWX` hurricane-window
upside risk-premium spikes that fail on the completed D1 bar mean-revert over a
short holding period.

This is a second XNG hurricane sleeve, but it is not the existing
`QM5_12601_eia-xng-hurr-brk`: 12601 is long-only continuation after an upside
channel breakout. This card is short-only, requires an upside spike to make a
new short-term high, then requires bearish rejection and a close near the low of
the signal bar before fading it.

Runtime data stays Darwinex MT5 OHLC and broker calendar only. The EA does not
read hurricane tracks, EIA production data, LNG flows, storage reports, futures
curves, CSV files, APIs, analyst forecasts, or ML models.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Trade only when the prior closed D1 bar is in the hurricane fade window:
  August 15 through October 31, inclusive.
- Short only.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if the current spread exceeds `strategy_max_spread_points`.
- Compute the prior closed D1 open, high, low, close, SMA(`strategy_trend_period`), ATR(`strategy_atr_period`), and the highest high of the previous `strategy_reject_lookback` completed D1 bars excluding the signal bar.
- Require the signal-bar high to equal or exceed that previous highest high.
- Require signal-bar range to be at least `strategy_min_range_atr * ATR`.
- Require upside stretch from high to SMA to be at least `strategy_min_stretch_atr * ATR`.
- Require the signal close to remain above SMA, so the fade is entered before full normalization.
- Require bearish rejection: close below open, body at least `strategy_min_body_ratio` of range, and close in the lower `strategy_reversal_tail_ratio` fraction of the D1 range.
- Entry: SELL `XNGUSD.DWX` at market with a hard ATR stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the prior completed D1 close returns to or below SMA(`strategy_trend_period`).
- Exit when the prior completed D1 close breaks above the highest high of the previous `strategy_exit_channel` completed bars, excluding the signal bar.
- Exit when the broker date leaves the August 15 through October 31 fade window.
- Exit when the position has been held for more than `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XNGUSD.DWX` on D1.
- Magic slot must be 0.
- No long entries in v1.
- Skip entries when ATR, SMA, channel, range, or calendar values are unavailable.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_start_month
  default: 8
  sweep_range: [8]
- name: strategy_start_day
  default: 15
  sweep_range: [15]
- name: strategy_end_month
  default: 10
  sweep_range: [10]
- name: strategy_end_day
  default: 31
  sweep_range: [15, 31]
- name: strategy_reject_lookback
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_exit_channel
  default: 10
  sweep_range: [7, 10, 15]
- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 1.00
  sweep_range: [0.80, 1.00, 1.30]
- name: strategy_min_body_ratio
  default: 0.30
  sweep_range: [0.25, 0.30, 0.40]
- name: strategy_reversal_tail_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.45]
- name: strategy_min_stretch_atr
  default: 1.25
  sweep_range: [1.0, 1.25, 1.75]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.5, 3.25, 4.0]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [5, 7, 10]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA or NOAA. The sources are used only
for official structural lineage: Atlantic hurricanes can create natural-gas
supply, demand, LNG export, and infrastructure risk. Q02+ must validate whether
the mechanical failed-spike fade has value on Darwinex `XNGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 25
- expected_trade_frequency: approximately 3-7 trades/year.
- risk_class: high for natural-gas volatility and event-gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA energy-market hurricane risk material plus NOAA/NHC climatology.
- [x] R2 mechanical: fixed hurricane fade window, D1 failed-spike rejection, ATR/SMA/channel/time exits, and ATR stop.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external runtime feed, or more than one position per magic.
- [x] Non-duplicate: XNG hurricane failed-spike fade is not `QM5_12601` breakout continuation, XNG winter freeze-off fade, shoulder-season short, storage event logic, LNG breakout, broad monthly XNG seasonality, weekend gap, XTI/XNG basket, XAU/XAG metal logic, or `QM5_12567` RSI commodity pullback.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, magic slot guard, parameter guard, spread cap, and hurricane fade calendar window.
- trade_entry: short-only D1 failed-spike rejection after a hurricane-window upside new high and ATR/SMA stretch.
- trade_management: close on SMA normalization, exit-channel invalidation, season end, or max-hold timeout.
- trade_close: hard ATR stop plus framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial structural XNG hurricane failed-spike fade build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PENDING | `artifacts/qm5_12861_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | PENDING | paced fleet enqueue after Q01 PASS |
