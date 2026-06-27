---
ea_id: QM5_12609
slug: wti-cad-spread-mr
type: strategy
source_id: BOC-CAD-OIL-SPREAD-2026
source_citation: "Bank of Canada. The Link Between the Canadian Dollar and Commodity Prices: Has It Broken? Staff Analytical Note 2017-1. URL https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/; Chen, Rogoff, and Rossi. Can Exchange Rates Forecast Commodity Prices? Quarterly Journal of Economics, 2010. URL https://academic.oup.com/qje/article/125/3/1145/1903425; U.S. Energy Information Administration. Canada Country Analysis Brief. URL https://www.eia.gov/international/analysis/country/CAN"
sources:
  - "[[sources/BOC-CAD-OIL-SPREAD-2026]]"
concepts:
  - "[[concepts/petro-currency-spread]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/wti-energy-sleeve]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [petro-currency-spread, market-neutral-basket, zscore-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, USDCAD.DWX]
logical_symbol: QM5_12609_XTI_USDCAD_SPREAD_D1
period: D1
expected_trade_frequency: "D1 WTI/USDCAD petro-currency spread z-score basket; estimate 4-10 spread packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS central-bank, academic, and U.S. government source packet; R2 PASS deterministic D1 WTI/USDCAD log-spread z-score basket; R3 PASS XTIUSD.DWX and USDCAD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# WTI CAD Spread Mean Reversion

## Source

- Source: [[sources/BOC-CAD-OIL-SPREAD-2026]]
- Primary citation: Bank of Canada, "The Link Between the Canadian Dollar and
  Commodity Prices: Has It Broken?", Staff Analytical Note 2017-1, URL
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/.
- Academic support: Chen, Rogoff, and Rossi, "Can Exchange Rates Forecast
  Commodity Prices?", Quarterly Journal of Economics, 2010, URL
  https://academic.oup.com/qje/article/125/3/1145/1903425.
- Energy-market context: U.S. Energy Information Administration, "Canada",
  Country Analysis Brief, URL
  https://www.eia.gov/international/analysis/country/CAN.

## Concept

WTI and the Canadian dollar share an oil-exporter structural channel, but the
relationship is not a one-way forecast and can decouple by regime. This card
therefore trades the relationship as a two-leg spread rather than using CAD as a
standalone predictor. The EA computes:

`spread = ln(XTIUSD.DWX) + beta * ln(USDCAD.DWX)`

Because USDCAD rises when CAD weakens, a high spread means WTI is rich and/or
CAD is weak versus the recent petro-currency relationship. The package shorts
that spread by selling both XTIUSD.DWX and USDCAD.DWX. A low spread buys both
legs. The thesis is mean reversion of the cross-market relationship, not an
outright WTI trend or calendar seasonal effect.

This is deliberately different from:

- `QM5_12607_wti-cad-confirm`: this card trades both XTIUSD.DWX and USDCAD.DWX
  as a basket; 12607 trades only XTIUSD.DWX with USDCAD as a read-only
  confirmation filter.
- `QM5_12603_wti-tsmom12m`: not monthly WTI-only momentum.
- `QM5_12576`, `QM5_12579`, `QM5_12590`, `QM5_12591`, `QM5_12592`,
  `QM5_12593`, `QM5_12596`, `QM5_12597`, `QM5_12598`, `QM5_12599`, and
  `QM5_12600`: not EIA inventory timing, hurricane, refinery, weekday/month,
  OPEC, or CME expiry logic.
- `QM5_12604`, `QM5_12605`, `QM5_12606`, and `QM5_12608`: not oil/metal or
  oil/gas ratio logic.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Host symbol: XTIUSD.DWX.
- Basket leg symbols: XTIUSD.DWX and USDCAD.DWX.
- Logical symbol: QM5_12609_XTI_USDCAD_SPREAD_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no Bank of Canada feed, EIA feed,
  futures curve, macro CSV, COT report, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) + beta * ln(USDCAD.DWX close)` on
  prior completed D1 bars.
- Compute a rolling z-score of the latest completed spread against the prior
  `strategy_z_lookback_d1` completed spreads.
- Short spread: if z-score is above `strategy_entry_z`, SELL XTIUSD.DWX and
  SELL USDCAD.DWX.
- Long spread: if z-score is below `-strategy_entry_z`, BUY XTIUSD.DWX and BUY
  USDCAD.DWX.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(`strategy_atr_period_d1`)
  * `strategy_atr_sl_mult` from entry.
- Exit both legs when absolute spread z-score falls below `strategy_exit_z`.
- Exit both legs after `strategy_max_hold_days`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Host chart must be XTIUSD.DWX on D1.
- Skip entries when XTI spread exceeds `strategy_xti_max_spread_pts`.
- Skip entries when USDCAD spread exceeds `strategy_usdcad_max_spread_pts`.
- Skip entries when either close series or either ATR series is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open two-leg package at a time.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 90
  sweep_range: [60, 90, 120, 180]
- name: strategy_beta
  default: 4.0
  sweep_range: [3.0, 4.0, 6.0]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.6, 2.0, 2.4]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 60]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_usdcad_max_spread_pts
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

No performance claim is imported from the sources. The sources support the
structural lineage for a WTI/CAD relationship and commodity-currency linkage.
Q02+ must test whether this deterministic, low-frequency basket has an edge on
Darwinex `XTIUSD.DWX` and `USDCAD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-10 spread packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: central-bank note, peer-reviewed academic paper, and
  U.S. government energy country analysis.
- [x] R2 mechanical: fixed z-score entry, z-score exit, ATR hard stops, broken
  package repair, and max-hold exit.
- [x] R3 testable: XTIUSD.DWX and USDCAD.DWX exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  external runtime feed, and no live/autotrading action.
- [x] Non-duplicate: it is a two-leg WTI/CAD mean-reversion basket, not the
  WTI-only CAD confirmation build or any existing WTI calendar, EIA, ratio,
  expiry, OPEC, hurricane, refinery, Donchian, or RSI sleeve.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, and spread caps.
- trade_entry: two-leg basket entry on WTI/USDCAD log-spread z-score extremes.
- trade_management: package integrity repair only.
- trade_close: z-score reversion exit, max-hold exit, Friday close, and
  per-leg ATR hard stops.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI/CAD spread basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
