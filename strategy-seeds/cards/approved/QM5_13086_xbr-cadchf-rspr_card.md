---
ea_id: QM5_13086
slug: xbr-cadchf-rspr
type: strategy
strategy_id: EIA-BOC-XBR-CADCHF-2026
source_id: EIA-BOC-XBR-CADCHF-2026
source_citation: "EIA oil/exchange-rate working paper plus official Bank of Canada commodity-CAD and EIA Canada energy-export context."
source_citations:
  - type: government_research
    citation: "Beckmann, Czudaj, and Arora. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, 2017."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_research
    citation: "Bank of Canada Staff Analytical Note 2017-1. The Link Between the Canadian Dollar and Commodity Prices: Has It Broken?"
    location: "https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/"
    quality_tier: A
    role: cad_channel
  - type: government_energy_profile
    citation: "U.S. Energy Information Administration. Canada Country Analysis Brief."
    location: "https://www.eia.gov/international/analysis/country/CAN"
    quality_tier: A
    role: energy_export_context
sources:
  - "[[sources/EIA-BOC-XBR-CADCHF-2026]]"
concepts:
  - "[[concepts/oil-fx-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/energy-sleeve]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [brent-fx-return-spread, market-neutral-basket, zscore-reversion, atr-hard-stop, time-stop, low-frequency, energy]
target_symbols: [XBRUSD.DWX, CADCHF.DWX]
basket_symbols: [XBRUSD.DWX, CADCHF.DWX]
markets: [XBRUSD.DWX, CADCHF.DWX]
primary_target_symbols: [XBRUSD.DWX, CADCHF.DWX]
single_symbol_only: false
logical_symbol: QM5_13086_XBR_CADCHF_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XBR/CADCHF return-spread z-score reversion; estimate 5-10 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02_QUEUED
last_updated: 2026-07-22
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed commodity/energy sleeve 2026-07-09: R1 PASS official EIA oil/exchange-rate research plus Bank of Canada commodity-CAD and EIA Canada energy-export context; R2 PASS deterministic D1 two-leg XBR/CADCHF return-spread z-score reversion with spread caps, mean exit, max-hold exit, package repair, and ATR hard stops; R3 PASS XBRUSD.DWX already registered in framework magic rows and CADCHF.DWX exists in DWX matrix; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is Brent/CADCHF oil-FX relative value, not QM5_13011 XTI/CADCHF, QM5_13005 XBR/USDCAD, XBR/AUDCAD, XBR/CADJPY, Brent calendar/seasonality, XTI/XNG, XAU/XAG, XNG, index, or commodity-RSI logic."
---

# XBR/CADCHF D1 Return-Spread Reversion

## Source

- Source: [[sources/EIA-BOC-XBR-CADCHF-2026]]
- Primary citation: Beckmann, Czudaj, and Arora, "The Relationship between Oil
  Prices and Exchange Rates", U.S. Energy Information Administration Working
  Paper, 2017.
- Support: Bank of Canada Staff Analytical Note 2017-1 for the commodity/CAD
  channel and EIA Canada country analysis for structural energy-export context.

## Concept

This card adds a Brent-linked energy/FX relative-value sleeve without using the
current XAU, SP500, NDX, or XNG book exposure. It compares completed Brent
returns with completed CADCHF returns:

`return_spread = ln(XBR[t] / XBR[t-L]) - beta_cadchf * ln(CADCHF[t] / CADCHF[t-L])`

CADCHF normally rises when CAD strengthens versus CHF. A high positive spread
means Brent has rallied more than the CADCHF confirmation leg; the basket fades
that by selling Brent and buying CADCHF. A low negative spread means Brent is
cheap versus CADCHF; the basket buys Brent and sells CADCHF.

This is deliberately different from:

- `QM5_13011_xti-cadchf-rspr`: that uses WTI, not Brent.
- `QM5_13005_xbr-cad-rspr`: that uses USDCAD and therefore keeps a broad USD
  leg rather than a CAD/CHF cross.
- `QM5_13079_xbr-audcad-rspr`: that tests AUDCAD commodity-FX behaviour, not
  CADCHF defensive-FX confirmation.
- `QM5_13083_xbr-cadjpy-rspr`: that tests an oil-exporter/oil-importer cross.
- Brent calendar, weekday, 52-week, reversal, and TSMOM sleeves: this is a
  two-leg return-spread basket, not outright Brent timing.
- XTI/XNG, Brent/XNG, oil/metal, XAU/XAG, XNG, index, and commodity-RSI logic.

## Markets And Timeframe

- Logical symbol: `QM5_13086_XBR_CADCHF_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`.
- Basket legs: `XBRUSD.DWX` and `CADCHF.DWX`.
- Period: D1.
- Expected trade frequency: about 5-10 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread metadata, ATR, broker time, and
  V5 framework state only. No EIA, Bank of Canada, futures curve, CFTC,
  macro CSV, API, analyst forecast, or ML model is consumed at runtime.

## Entry Rules

- Evaluate only on a new D1 bar of the `XBRUSD.DWX` host chart.
- Copy completed D1 closes for `XBRUSD.DWX` and `CADCHF.DWX`.
- Compute `xbr_ret = ln(XBR close[1] / XBR close[1 + strategy_return_lookback_d1])`.
- Compute `cadchf_ret = ln(CADCHF close[1] / CADCHF close[1 + strategy_return_lookback_d1])`.
- Compute `return_spread = xbr_ret - strategy_beta_cadchf * cadchf_ret`.
- Standardize the latest completed return spread against the prior
  `strategy_z_lookback_d1` completed return spreads.
- Short spread: if z-score is above `strategy_entry_z`, sell `XBRUSD.DWX` and
  buy `CADCHF.DWX`.
- Long spread: if z-score is below `-strategy_entry_z`, buy `XBRUSD.DWX` and
  sell `CADCHF.DWX`.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(`strategy_atr_period_d1`)
  times `strategy_atr_sl_mult` from entry.
- Exit both legs when absolute spread z-score falls below `strategy_exit_z`.
- Exit both legs after `strategy_max_hold_days`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Only run from the `XBRUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Skip entries when `XBRUSD.DWX` spread exceeds `strategy_xbr_max_spread_pts`.
- Skip entries when `CADCHF.DWX` spread exceeds `strategy_cadchf_max_spread_pts`.
- Skip entries when either close series or either ATR series is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open two-leg package at a time.
- Package integrity repair is deterministic: if one leg is missing, close the
  remaining leg.

## Parameters To Test

- name: strategy_return_lookback_d1
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta_cadchf
  default: 0.55
  sweep_range: [0.35, 0.55, 0.80]
- name: strategy_entry_z
  default: 1.9
  sweep_range: [1.6, 1.9, 2.2]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.25, 0.4, 0.6]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 30
  sweep_range: [20, 30, 45]
- name: strategy_xbr_max_spread_pts
  default: 1200
  sweep_range: [800, 1200, 1800]
- name: strategy_cadchf_max_spread_pts
  default: 80
  sweep_range: [60, 80, 120]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

The source packet establishes structural lineage for oil/exchange-rate and
commodity-CAD channels only. This card imports no source performance number.
Q02 and later phases must validate or reject the `XBRUSD.DWX` / `CADCHF.DWX`
basket on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 5-10 paired packages/year.
- risk_class: medium-high because Brent volatility, CADCHF liquidity/spread,
  and synchronized basket fills need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA research plus official Bank of Canada
  and EIA Canada support.
- [x] R2 mechanical: fixed D1 return spread, rolling z-score entry/exit, ATR
  hard stops, spread caps, max-hold exit, and broken-package repair.
- [x] R3 testable: `XBRUSD.DWX` is already registered in framework magic rows
  for Brent builds and `CADCHF.DWX` exists in the DWX matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Non-duplicate: paired Brent/CADCHF return-spread mean reversion, not the
  existing XTI/CADCHF, XBR/USDCAD, XBR/AUDCAD, XBR/CADJPY, XBR/XNG, Brent
  calendar, WTI/CAD, XTI/XNG, XAU/XAG, XNG, index, or commodity-RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Registry And Queue Notes

- Slot 0: `XBRUSD.DWX`.
- Slot 1: `CADCHF.DWX`.
- Use the logical basket setfile `QM5_13086_XBR_CADCHF_RSPREAD_D1` for Q02.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps, news,
  Friday close, and valid data checks.
- trade_entry: D1 standardized XBR/CADCHF return-spread reversion.
- trade_management: broken-package repair and max-hold tracking.
- trade_close: z-score mean exit, max-hold exit, Friday close, and ATR hard
  stops.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce at least one valid logical-basket
trade, if Q02 PF is below 1.0 after costs, if synchronized XBR/CADCHF history
is insufficient, or if the basket preflight cannot execute both legs under the
V5 one-position-per-magic model.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XBR/CADCHF return-spread basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q02 Structural Smoke | 2026-07-22 | QUEUED | `D:/QM/reports/pipeline/mt5_queue.db` row 3 |
