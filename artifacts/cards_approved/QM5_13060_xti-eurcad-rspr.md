---
ea_id: QM5_13060
slug: xti-eurcad-rspr
type: strategy
strategy_id: BOC-EURCAD-OIL-RSPREAD-2026
source_id: BOC-EURCAD-OIL-RSPREAD-2026
source_citation: "EIA oil/exchange-rate working paper, Bank of Canada CAD commodity-currency note, and EIA Canada energy context."
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. The Relationship between Oil Prices and Exchange Rates: Theory and Evidence. June 2017."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_research
    citation: "Bank of Canada Staff Analytical Note 2017-1. The Share of Systematic Variations in the Canadian Dollar-Part II."
    location: "https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/"
    quality_tier: A
    role: cad_channel
  - type: government_energy_context
    citation: "U.S. Energy Information Administration. Canada Country Analysis Brief."
    location: "https://www.eia.gov/international/analysis/country/CAN"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/BOC-EURCAD-OIL-RSPREAD-2026]]"
concepts:
  - "[[concepts/oil-cad-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/energy-fx-sleeve]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [oil-fx-return-spread, market-neutral-basket, inverse-cad-quote, zscore-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, EURCAD.DWX]
basket_symbols: [XTIUSD.DWX, EURCAD.DWX]
markets: [XTIUSD.DWX, EURCAD.DWX]
primary_target_symbols: [XTIUSD.DWX, EURCAD.DWX]
single_symbol_only: false
logical_symbol: QM5_13060_XTI_EURCAD_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XTI/EURCAD inverse-CAD return-spread z-score reversion; estimate 6-12 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.06
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-08: R1 PASS EIA and Bank of Canada source packet; R2 PASS deterministic D1 XTI/EURCAD inverse-CAD return-spread basket; R3 PASS XTIUSD.DWX and EURCAD.DWX exist in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime data."
---

# XTI/EURCAD D1 Return-Spread Reversion

## Source

- Source: [[sources/BOC-EURCAD-OIL-RSPREAD-2026]]
- Primary citation: EIA working paper, "The Relationship between Oil Prices
  and Exchange Rates: Theory and Evidence", URL
  https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf.
- CAD channel: Bank of Canada Staff Analytical Note 2017-1, "The Share of
  Systematic Variations in the Canadian Dollar-Part II", URL
  https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/.
- Support: EIA Canada Country Analysis Brief, URL
  https://www.eia.gov/international/analysis/country/CAN.

## Concept

Oil prices and the Canadian dollar have a documented structural relationship,
but the relationship is regime-dependent and not a one-way predictor. This card
trades a two-leg relative-value package instead of an outright WTI forecast.

`EURCAD` rises when CAD weakens against EUR. Because the oil/CAD channel is
inverse in this quote, the implemented dislocation is:

`return_spread = ln(XTI[t] / XTI[t-L]) + beta_eurcad * ln(EURCAD[t] / EURCAD[t-L])`

When WTI has unusually outperformed while EURCAD has also risen, the package
fades a "oil up while CAD weak" divergence by selling both WTI and EURCAD. When
WTI has unusually underperformed while EURCAD has also fallen, it buys both WTI
and EURCAD.

This is deliberately different from:

- `QM5_12607_wti-cad-confirm`: USDCAD confirmation filter for an outright WTI
  position.
- `QM5_12609_wti-cad-spread-mr` and `QM5_12722_wti-cad-brk`: USDCAD-specific
  spread/breakout definitions.
- `QM5_13010_xti-cadjpy-rspr`, `QM5_13011_xti-cadchf-rspr`, and
  `QM5_13034_xti-audcad-rspr`: different CAD crosses and different quotation
  mechanics.
- `QM5_13029_gbpcad-gbpnzd-coint` and `QM5_13058_audcad-gbpnzd-coint`:
  FX-only CAD-cross cointegration baskets, not energy/FX oil-CAD sleeves.
- XAU/XAG, XNG, index, Brent/WTI, XTI/XNG, oil/metals, and single-symbol WTI
  trend/seasonality sleeves.

## Markets And Timeframe

- Logical symbol: `QM5_13060_XTI_EURCAD_RSPREAD_D1`.
- Host symbol: `XTIUSD.DWX`.
- Basket legs: `XTIUSD.DWX` and `EURCAD.DWX`.
- Period: D1.
- Expected trade frequency: about 6-12 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread metadata, ATR, broker time, and
  V5 framework state only. No EIA, Bank of Canada, futures-curve, inventory,
  CFTC, macro CSV, API, analyst forecast, or ML model is consumed at runtime.

## Entry Rules

- Evaluate only on a new D1 bar of the `XTIUSD.DWX` host chart.
- Copy completed D1 closes for `XTIUSD.DWX` and `EURCAD.DWX`.
- Compute `xti_ret = ln(XTI close[1] / XTI close[1 + strategy_return_lookback_d1])`.
- Compute `eurcad_ret = ln(EURCAD close[1] / EURCAD close[1 + strategy_return_lookback_d1])`.
- Compute `return_spread = xti_ret + strategy_beta_eurcad * eurcad_ret`.
- Standardize the latest completed return spread against the prior
  `strategy_z_lookback_d1` completed return spreads.
- Short spread: if z-score is above `strategy_entry_z`, sell `XTIUSD.DWX` and
  sell `EURCAD.DWX`.
- Long spread: if z-score is below `-strategy_entry_z`, buy `XTIUSD.DWX` and
  buy `EURCAD.DWX`.
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

- Only run from the `XTIUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Skip entries when `XTIUSD.DWX` spread exceeds `strategy_xti_max_spread_pts`.
- Skip entries when `EURCAD.DWX` spread exceeds `strategy_eurcad_max_spread_pts`.
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
- name: strategy_beta_eurcad
  default: 0.60
  sweep_range: [0.40, 0.60, 0.85]
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
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_eurcad_max_spread_pts
  default: 160
  sweep_range: [100, 160, 240]

## Author Claims

The source packet establishes structural lineage for the oil/exchange-rate and
CAD commodity-currency channel only. This card imports no source performance
number. Q02 and later phases must validate or reject the `XTIUSD.DWX` /
`EURCAD.DWX` basket on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.06.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 6-12 paired packages/year.
- risk_class: medium-high because crude volatility, EURCAD liquidity, and
  synchronized basket fills need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: U.S. government energy research plus central-bank
  CAD commodity-currency research.
- [x] R2 mechanical: fixed D1 return spread, rolling z-score entry/exit, ATR
  hard stops, spread caps, max-hold exit, and broken-package repair.
- [x] R3 testable: `XTIUSD.DWX` and `EURCAD.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Non-duplicate: paired WTI/EURCAD inverse-CAD return-spread mean
  reversion, not WTI/USDCAD, WTI/CADJPY, WTI/CADCHF, WTI/AUDCAD,
  FX-only CAD-cross cointegration, XTI/NZD, XTI/XNG, Brent/CAD, Brent/WTI,
  metal-ratio, XNG, index, or outright WTI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Registry And Queue Notes

- Slot 0: `XTIUSD.DWX`.
- Slot 1: `EURCAD.DWX`.
- Use the logical basket setfile `QM5_13060_XTI_EURCAD_RSPREAD_D1` for Q02.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps, news,
  Friday close, and valid data checks.
- trade_entry: D1 standardized XTI/EURCAD inverse-CAD return-spread reversion.
- trade_management: broken-package repair and max-hold tracking.
- trade_close: z-score mean exit, max-hold exit, Friday close, and ATR hard
  stops.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce at least one valid logical-basket
trade, if Q02 PF is below 1.0 after costs, if synchronized XTI/EURCAD history
is insufficient, or if the basket preflight cannot execute both legs under the
V5 one-position-per-magic model.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-08 | initial XTI/EURCAD return-spread basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PENDING | `artifacts/qm5_13060_build_result.json` |
| Q02 Baseline Screening | 2026-07-08 | PENDING | enqueue after compile |
