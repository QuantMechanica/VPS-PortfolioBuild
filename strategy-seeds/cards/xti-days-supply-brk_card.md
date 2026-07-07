---
ea_id: QM5_13040
slug: xti-days-supply-brk
type: strategy
strategy_id: EIA-XTI-DAYS-SUPPLY-BRK-2026
source_id: EIA-XTI-DAYS-SUPPLY-BRK-2026
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
strategy_type_flags: [donchian-breakout, trend-filter-ma, atr-hard-stop, time-stop, long-only]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13040_XTI_DAYS_SUPPLY_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly capped WPSR-window tight-cover breakout; estimate 3-8 entries/year before Q02."
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

# XTI Days-of-Supply Tight-Cover Breakout

## Hypothesis

The EIA crude-oil days-of-supply series measures stock cover rather than
headline barrel inventory alone. Tight stock-cover regimes can amplify WTI
trend continuation when the market makes a fresh D1 breakout during the regular
weekly petroleum information window. This card does not forecast the EIA
series and does not ingest EIA data at runtime. It uses the official
days-of-supply/WPSR source family as structural lineage, then tests a
price-only `XTIUSD.DWX` D1 proxy.

## Source

- U.S. Energy Information Administration, "Crude Oil Days of Supply":
  https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
- U.S. Energy Information Administration, "Weekly Petroleum Status Report":
  https://www.eia.gov/petroleum/supply/weekly/

## Concept

The runtime proxy is deliberately simple: when WTI closes near the upper band
of its medium-term D1 close channel and breaks a prior Donchian high on a
Wednesday/Thursday WPSR proxy bar after a short pullback, go long once for that
broker-calendar month. The monthly cap keeps the rule low-frequency and avoids
stacking repeated weekly breakouts from the same stock-cover impulse.

This is deliberately different from:

- `QM5_12988_xti-eia-inventory-momentum`: two same-direction WPSR reaction
  bars plus breakout confirmation, not a monthly tight-cover proxy.
- `QM5_12579_eia-wti-aftershock`, `QM5_12590_eia-wti-wpsr-fade`,
  `QM5_12592_eia-wti-prewpsr`, and `QM5_12752_eia-wti-wpsr-idbrk`: not one-bar
  aftershock/fade/pre-event/inside-bar logic.
- `QM5_13028_xti-prod-brk`, `QM5_13035_xti-prod-sup-brk`, and
  `QM5_13039_xti-gasdraw-mom`: not field production, product-supplied demand,
  or gasoline-stock pressure.
- SPR, Cushing, refinery, hurricane, OPEC/IEA/MOMR/STEO, DPR, PSM, COT,
  rig-count, roll, expiry, month-only seasonality, WTI/Brent, XTI/XNG,
  oil-metal, XNG, XAU/XAG, and commodity RSI sleeves.

## Rules

- Trade only `XTIUSD.DWX` on D1 with `qm_magic_slot_offset=0`.
- Evaluate only after a completed D1 bar.
- The inspected bar must be Wednesday or Thursday in broker time, proxying the
  normal WPSR release window.
- Only one new entry is allowed per broker-calendar month.
- The inspected bar must be bullish, must close in the upper part of its range,
  and must have range at least `strategy_min_range_atr * ATR(20)`.
- It must close above the prior `strategy_breakout_lookback` D1 high,
  excluding the inspected bar.
- It must close in at least the upper `strategy_min_anchor_position` fraction
  of the `strategy_anchor_lookback` D1 close channel.
- A short pullback must exist before the signal: the inspected close must be at
  least `strategy_min_pullback_atr * ATR(20)` above the lowest close in the
  prior pullback window.
- The inspected close must be above `SMA(50)`, and `SMA(50)` must be rising
  versus `strategy_sma_slope_shift` completed D1 bars earlier.
- Enter long at market with ATR hard stop and ATR target. No shorts.
- Exit on ATR stop, ATR target, max hold, or a completed D1 close back below
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
- name: strategy_breakout_lookback
  default: 55
  sweep_range: [34, 55, 84]
- name: strategy_anchor_lookback
  default: 126
  sweep_range: [84, 126, 189]
- name: strategy_pullback_lookback
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_min_pullback_atr
  default: 0.40
  sweep_range: [0.25, 0.40, 0.65]
- name: strategy_min_anchor_position
  default: 0.70
  sweep_range: [0.60, 0.70, 0.80]
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

- [x] R1 official source: EIA days-of-supply series and WPSR pages.
- [x] R2 mechanical: fixed weekday proxy, monthly cap, Donchian breakout,
  stock-cover price proxy, SMA trend gate, ATR stop/target, and time/trend
  exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: WPSR proxy weekday, monthly cap, Donchian breakout, upper
  anchor-channel position, pullback reclaim, and rising SMA.
- trade_management: ATR target/stop via entry request plus SMA and max-hold
  exits.
- trade_close: deterministic time/trend exits and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-07 | initial days-of-supply tight-cover breakout build | Q02 | enqueue target |
