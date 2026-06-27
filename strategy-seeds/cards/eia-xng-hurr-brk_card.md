---
ea_id: QM5_12601
slug: eia-xng-hurr-brk
type: strategy
source_id: EIA-NOAA-XNG-HURR-2026
source_citation: "U.S. Energy Information Administration. Forecast strong hurricane season presents risk for U.S. oil and natural gas industry. Today in Energy, 2024-06-13. URL https://www.eia.gov/todayinenergy/detail.php?id=62104; NOAA National Hurricane Center. Tropical Cyclone Climatology. URL https://www.nhc.noaa.gov/climo/"
sources:
  - "[[sources/EIA-NOAA-XNG-HURR-2026]]"
concepts:
  - "[[concepts/natural-gas-hurricane-risk]]"
  - "[[concepts/supply-risk-breakout]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, long-only]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12601_XNG_HURR_BRK_D1
period: D1
expected_trade_frequency: "Peak Atlantic hurricane-season D1 natural-gas supply-risk breakout during August 15 through October 15; estimate 4-8 trades/year after channel, trend, range, and spread filters."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
expected_pf: 1.12
expected_dd_pct: 22.0
g0_approval_reasoning: "R1 PASS official EIA hurricane energy-market source plus NOAA/NHC climatology; R2 PASS deterministic peak-window D1 channel/SMA/ATR breakout rules; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# EIA XNG Hurricane-Season Supply-Risk Breakout

## Source

- Source: [[sources/EIA-NOAA-XNG-HURR-2026]]
- Primary citation: U.S. Energy Information Administration, "Forecast strong hurricane season presents risk for U.S. oil and natural gas industry", Today in Energy, 2024-06-13, URL https://www.eia.gov/todayinenergy/detail.php?id=62104.
- Supplemental citation: NOAA National Hurricane Center, Tropical Cyclone Climatology, URL https://www.nhc.noaa.gov/climo/.
- Supplemental citation: U.S. Energy Information Administration, "Hurricane Ida disrupted crude oil production and refining activity", Today in Energy, 2021-09-14, URL https://www.eia.gov/todayinenergy/detail.php?id=49576.

## Concept

EIA documents that Atlantic hurricanes can disrupt U.S. energy markets by
interrupting Gulf of Mexico oil and natural gas production, LNG export flows,
and related infrastructure. NOAA/NHC identifies the Atlantic hurricane season
and the peak activity cluster around mid-August through mid-October. This card
mechanizes that structural supply-risk window as a low-frequency XNGUSD.DWX D1
breakout sleeve: trade only when natural gas itself confirms upside pressure
during the peak window.

Runtime data stays Darwinex MT5 OHLC only. The EA does not read hurricane
tracks, EIA production data, LNG exports, weather feeds, storage reports,
futures curves, CSV files, APIs, analyst forecasts, or ML models.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon cumulative RSI pullback logic.
- `QM5_12575_eia-xng-season`: broad monthly two-sided natural-gas season map.
- `QM5_12582_chan-ng-spring`: fixed spring long-only calendar window.
- `QM5_12584_eia-xng-storage`: weekly storage-report aftershock continuation.
- `QM5_12586_eia-xng-winter-brk`: winter withdrawal-season breakout.
- `QM5_12587_eia-xng-inj-brk`: April-October downside Donchian breakdown.
- `QM5_12588_eia-xng-sum-sqz`: summer power-demand compression breakout.
- `QM5_12595_eia-xng-shfade`: shoulder-season failed-rally short mean reversion.
- `QM5_12591_eia-wti-hurr-brk`: WTI hurricane supply-risk breakout, not XNG.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Trade only when the prior closed D1 bar is in the peak Atlantic hurricane
  window: August 15 through October 15, inclusive.
- Long only.
- No entry if an open XNGUSD.DWX position already exists for this EA magic.
- No entry if the current spread exceeds `strategy_max_spread_points`.
- Compute the prior closed D1 close, SMA(`strategy_trend_period`),
  ATR(`strategy_atr_period`), prior `strategy_entry_channel` high/low, and
  signal-bar close location.
- Entry: BUY XNGUSD.DWX when the prior close breaks above the highest high of
  the previous `strategy_entry_channel` completed D1 bars, closes above SMA,
  has range at least `strategy_min_range_atr * ATR`, and closes in the top
  `strategy_min_close_location` fraction of the D1 range.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit when the broker date leaves the peak hurricane window.
- Exit when prior closed D1 close breaks below the lowest low of the previous
  `strategy_exit_channel` completed D1 bars.
- Exit when prior closed D1 close falls below SMA(`strategy_trend_period`).
- Exit when the position has been held for more than
  `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XNGUSD.DWX on D1.
- No short entries in v1.
- Skip entries when SMA, ATR, channel, range, or calendar values are unavailable.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_entry_channel
  default: 20
  sweep_range: [15, 20, 30, 40]
- name: strategy_exit_channel
  default: 10
  sweep_range: [7, 10, 15, 20]
- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.75
  sweep_range: [0.60, 0.75, 1.00]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 4.5]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [7, 12, 18]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA or NOAA. The sources are used only
for official structural lineage: the Atlantic hurricane peak window can create
natural-gas supply and infrastructure risk, and the EA waits for XNGUSD.DWX to
confirm a D1 upside breakout before entering.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 22
- expected_trade_frequency: approximately 4-8 trades/year.
- risk_class: high for natural-gas volatility and event-gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA energy-market hurricane risk material plus NOAA/NHC climatology.
- [x] R2 mechanical: fixed peak-season window, D1 channel/SMA breakout, ATR range filter, ATR stop, deterministic exits.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: XNG hurricane supply-risk breakout is not RSI pullback, storage aftershock, broad seasonality, spring calendar, winter breakout, injection breakdown, summer squeeze, or shoulder fade logic.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, peak-window entry gate, spread cap, parameter sanity.
- trade_entry: peak hurricane-season D1 upside channel breakout with SMA, range, and close-location confirmation.
- trade_management: close on season end, failed breakout, SMA failure, or max-hold timeout.
- trade_close: hard ATR stop plus framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural XNG hurricane-season supply-risk breakout card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
