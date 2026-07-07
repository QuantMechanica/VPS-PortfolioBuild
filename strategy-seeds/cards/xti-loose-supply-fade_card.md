---
ea_id: QM5_13041
slug: xti-loose-supply-fade
type: strategy
strategy_id: EIA-XTI-DAYS-SUPPLY-FADE-2026
source_id: EIA-XTI-DAYS-SUPPLY-FADE-2026
source_citation: "U.S. Energy Information Administration crude oil days-of-supply series and Weekly Petroleum Status Report pages."
source_citations:
  - type: official_data_series
    citation: "U.S. Energy Information Administration. Crude Oil Days of Supply."
    location: "https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm"
    quality_tier: A
    role: primary
  - type: official_weekly_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: supplement
strategy_type_flags: [donchian-breakout, trend-filter-ma, atr-hard-stop, time-stop, short-only]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13041_XTI_LOOSE_SUPPLY_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly capped WPSR-window loose-cover breakdown; estimate 3-8 entries/year before Q02."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.06
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
---

# XTI Loose Days-Of-Supply Breakdown Fade

## Hypothesis

The EIA crude-oil days-of-supply series measures stock cover rather than
headline barrel inventory alone. Loose stock-cover regimes can amplify WTI
downside continuation when price breaks down during the regular weekly
petroleum information window. This card does not forecast the EIA series and
does not ingest EIA data at runtime. It uses the official days-of-supply/WPSR
source family as structural lineage, then tests a price-only `XTIUSD.DWX` D1
proxy.

## Source

- U.S. Energy Information Administration, "Crude Oil Days of Supply":
  https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
- U.S. Energy Information Administration, "Weekly Petroleum Status Report":
  https://www.eia.gov/petroleum/supply/weekly/

## Concept

The runtime proxy is deliberately simple: when WTI closes near the lower band
of its medium-term D1 close channel and breaks a prior Donchian low on a
Wednesday/Thursday WPSR proxy bar after a short rebound, sell once for that
broker-calendar month. The monthly cap keeps the rule low-frequency and avoids
stacking repeated weekly breakdowns from the same stock-cover impulse.

This is deliberately different from:

- `QM5_13040_xti-days-supply-brk`: long-only tight-cover breakout with upper
  channel anchoring. This card is short-only, lower-channel, and uses falling
  trend confirmation.
- `QM5_12988_xti-eia-inventory-momentum`: two same-direction WPSR reaction
  bars plus breakout confirmation, not a monthly loose-cover proxy.
- `QM5_12579_eia-wti-aftershock`, `QM5_12590_eia-wti-wpsr-fade`,
  `QM5_12592_eia-wti-prewpsr`, and `QM5_12752_eia-wti-wpsr-idbrk`: not one-bar
  aftershock/fade/pre-event/inside-bar logic.
- `QM5_13028_xti-prod-brk`, `QM5_13035_xti-prod-sup-brk`,
  `QM5_13039_xti-gasdraw-mom`, `QM5_13001_xti-export-flow-brk`, and
  `QM5_13026_xti-import-flow-fade`: not field production, product-supplied
  demand, gasoline-stock pressure, export, or import-flow logic.
- SPR, Cushing, refinery, hurricane, OPEC/IEA/MOMR/STEO, DPR, PSM, COT,
  rig-count, roll, expiry, month-only seasonality, WTI/Brent, XTI/XNG,
  oil-metal, XNG, XAU/XAG, and commodity RSI sleeves.

## Rules

- Trade only `XTIUSD.DWX` on D1 with `qm_magic_slot_offset=0`.
- Evaluate only after a completed D1 bar.
- The inspected bar must be Wednesday or Thursday in broker time, proxying the
  normal WPSR release window.
- Only one new entry is allowed per broker-calendar month.
- The inspected bar must be bearish, must close in the lower part of its range,
  and must have range at least `strategy_min_range_atr * ATR(20)`.
- It must close below the prior `strategy_breakdown_lookback` D1 low, excluding
  the inspected bar.
- It must close no higher than `strategy_max_anchor_position` within the
  `strategy_anchor_lookback` D1 close channel.
- A short rebound must exist before the signal: the highest close in the prior
  rebound window must be at least `strategy_min_rebound_atr * ATR(20)` above
  the inspected close.
- The inspected close must be below `SMA(50)`, and `SMA(50)` must be falling
  versus `strategy_sma_slope_shift` completed D1 bars earlier.
- Enter short at market with ATR hard stop and ATR target. No longs.
- Exit on ATR stop, ATR target, max hold, or a completed D1 close back above
  `SMA(50)`.

## Risk

Q02 and later backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The build
is single-symbol, low-frequency, non-ML, non-grid, non-martingale, and uses no
runtime web/API/CSV/EIA feed. It does not touch live setfiles, `T_Live`,
AutoTrading, or the portfolio gate.

## Parameters To Test

- name: strategy_report_start_dow
  default: 3
  sweep_range: [3]
- name: strategy_report_end_dow
  default: 4
  sweep_range: [4]
- name: strategy_breakdown_lookback
  default: 55
  sweep_range: [34, 55, 84]
- name: strategy_anchor_lookback
  default: 126
  sweep_range: [84, 126, 189]
- name: strategy_rebound_lookback
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_min_rebound_atr
  default: 0.40
  sweep_range: [0.25, 0.40, 0.65]
- name: strategy_max_anchor_position
  default: 0.30
  sweep_range: [0.20, 0.30, 0.40]
- name: strategy_sma_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.55
  sweep_range: [0.40, 0.55, 0.80]
- name: strategy_min_close_location
  default: 0.60
  sweep_range: [0.55, 0.60, 0.70]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.50]
- name: strategy_atr_tp_mult
  default: 3.25
  sweep_range: [2.50, 3.25, 4.25]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [8, 12, 18]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for crude-oil stock-cover reporting and the WPSR cadence. The edge
claim is tested by the QM Q02+ pipeline on Darwinex `XTIUSD.DWX` bars.

## Strategy Allowability Check

- [x] R1 official source: one `source_id` with EIA days-of-supply/WPSR URLs.
- [x] R2 mechanical: fixed weekday proxy, monthly cap, Donchian breakdown,
  stock-cover price proxy, SMA trend gate, ATR stop/target, and time/trend
  exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: short loose-cover breakdown, not the existing long
  tight-cover breakout, WPSR momentum/fade/pre-event/inside-bar families,
  production/supply/import/export flows, Cushing, refinery, hurricane, OPEC,
  COT, rig-count, XTI/XNG, XNG, XAU/XAG, oil-metal, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: WPSR proxy weekday, monthly cap, Donchian breakdown, lower
  anchor-channel position, rebound rejection, and falling SMA.
- trade_management: ATR target/stop via entry request plus SMA and max-hold
  exits.
- trade_close: deterministic time/trend exits and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-07 | initial days-of-supply loose-cover breakdown build | Q02 | enqueue target |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-07 | APPROVED | this card |
