---
ea_id: QM5_12722
slug: wti-cad-brk
type: strategy
source_id: BOC-CAD-OIL-BRK-2026
source_citation: "Bank of Canada. The Link Between the Canadian Dollar and Commodity Prices: Has It Broken? Staff Analytical Note 2017-1. URL https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/; Chen, Rogoff, and Rossi. Can Exchange Rates Forecast Commodity Prices? Quarterly Journal of Economics, 2010. URL https://academic.oup.com/qje/article/125/3/1145/1903425; U.S. Energy Information Administration. Canada Country Analysis Brief. URL https://www.eia.gov/international/analysis/country/CAN"
sources:
  - "[[sources/BOC-CAD-OIL-BRK-2026]]"
concepts:
  - "[[concepts/petro-currency-spread]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/wti-energy-sleeve]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [petro-currency-spread, market-neutral-basket, pair-spread-breakout, atr-hard-stop, channel-exit, low-frequency]
target_symbols: [XTIUSD.DWX, USDCAD.DWX]
logical_symbol: QM5_12722_XTI_USDCAD_BRK_D1
period: D1
expected_trade_frequency: "D1 WTI/USDCAD petro-currency channel-breakout basket; estimate 4-10 spread packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS central-bank, academic, and U.S. government source packet; R2 PASS deterministic D1 WTI/USDCAD log-spread channel breakout; R3 PASS XTIUSD.DWX and USDCAD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.10
expected_dd_pct: 20.0
---

# WTI CAD Petro-Currency Breakout

## Source

- Source: [[sources/BOC-CAD-OIL-BRK-2026]]
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

Canada is a major energy exporter, so WTI and CAD can move together through a
petro-currency channel. This card trades that channel as a two-leg structural
breakout basket instead of a standalone WTI trend call:

`spread = ln(XTIUSD.DWX) - beta * ln(USDCAD.DWX)`

A high breakout means WTI is rising and/or CAD is strengthening versus the
recent channel; the package buys WTI and sells USDCAD. A low breakout sells WTI
and buys USDCAD. The thesis is continuation of a synchronized oil/CAD regime,
not z-score mean reversion.

This is deliberately different from:

- `QM5_12609_wti-cad-spread-mr`: that card fades z-score extremes in
  `ln(XTIUSD) + beta * ln(USDCAD)`; this card follows channel breakouts in
  `ln(XTIUSD) - beta * ln(USDCAD)`.
- `QM5_12607_wti-cad-confirm`: that card trades only XTIUSD with USDCAD as a
  read-only confirmation filter; this card trades both legs as a basket.
- `QM5_12603_wti-tsmom12m`: not monthly WTI-only time-series momentum.
- The EIA WTI event/calendar family: not inventory, refinery, hurricane, OPEC,
  expiry, weekday, or month-of-year logic.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Host symbol: XTIUSD.DWX.
- Basket leg symbols: XTIUSD.DWX and USDCAD.DWX.
- Logical symbol: QM5_12722_XTI_USDCAD_BRK_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no Bank of Canada feed, EIA feed,
  futures curve, macro CSV, COT report, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) - beta * ln(USDCAD.DWX close)` on
  prior completed D1 bars.
- Compute the highest and lowest spread over `strategy_entry_lookback_d1`,
  excluding the most recent closed spread.
- Long petro-currency spread: if the most recent closed spread is above the
  entry-channel high, BUY XTIUSD.DWX and SELL USDCAD.DWX.
- Short petro-currency spread: if the most recent closed spread is below the
  entry-channel low, SELL XTIUSD.DWX and BUY USDCAD.DWX.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(`strategy_atr_period_d1`)
  * `strategy_atr_sl_mult` from entry.
- Long package exit: close both legs when the spread falls below the
  `strategy_exit_lookback_d1` channel low.
- Short package exit: close both legs when the spread rises above the
  `strategy_exit_lookback_d1` channel high.
- Time stop: close both legs after `strategy_max_hold_days`.
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

- name: strategy_entry_lookback_d1
  default: 120
  sweep_range: [90, 120, 180, 252]
- name: strategy_exit_lookback_d1
  default: 40
  sweep_range: [20, 40, 60]
- name: strategy_beta
  default: 4.0
  sweep_range: [3.0, 4.0, 6.0]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 60
  sweep_range: [30, 60, 90]
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
structural lineage for a WTI/CAD commodity-currency channel. Q02+ must test
whether this deterministic, low-frequency basket has an edge on Darwinex
`XTIUSD.DWX` and `USDCAD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 4-10 spread packages/year.
- risk_class: high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: central-bank note, peer-reviewed academic paper, and
  U.S. government energy country analysis.
- [x] R2 mechanical: fixed channel breakout, channel exit, ATR hard stops,
  broken-package repair, and max-hold exit.
- [x] R3 testable: XTIUSD.DWX and USDCAD.DWX exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, no
  external runtime feed, and no live/autotrading action.
- [x] Non-duplicate: it is a two-leg WTI/CAD continuation basket, not the
  existing WTI/CAD z-score reversion build, WTI-only confirmation build, WTI
  calendar/event builds, ratio baskets, Donchian commodity trend, or RSI
  commodity logic.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps, and
  basket-leg availability.
- trade_entry: two-leg basket entry on WTI/CAD log-spread channel breakout.
- trade_management: package integrity repair and max-hold exit.
- trade_close: channel exit reversal, Friday close, and per-leg ATR hard stops.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI/CAD breakout basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
