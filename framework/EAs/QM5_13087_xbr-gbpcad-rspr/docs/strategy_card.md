---
ea_id: QM5_13087
slug: xbr-gbpcad-rspr
type: strategy
strategy_id: EIA-BOC-XBR-GBPCAD-2026
source_id: EIA-BOC-XBR-GBPCAD-2026
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
  - "[[sources/EIA-BOC-XBR-GBPCAD-2026]]"
concepts:
  - "[[concepts/oil-cad-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/energy-fx-sleeve]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [oil-fx-return-spread, market-neutral-basket, inverse-cad-quote, zscore-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XBRUSD.DWX, GBPCAD.DWX]
basket_symbols: [XBRUSD.DWX, GBPCAD.DWX]
markets: [XBRUSD.DWX, GBPCAD.DWX]
primary_target_symbols: [XBRUSD.DWX, GBPCAD.DWX]
single_symbol_only: false
logical_symbol: QM5_13087_XBR_GBPCAD_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XBR/GBPCAD inverse-CAD return-spread z-score reversion; estimate 6-12 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.06
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS EIA oil/exchange-rate research plus Bank of Canada oil/CAD systematic-variation support and EIA Canada energy context; R2 PASS deterministic D1 XBR/GBPCAD inverse-CAD return-spread basket with fixed return window, rolling z-score, spread caps, mean exit, max-hold exit, and ATR hard stops; R3 PASS XBRUSD.DWX and GBPCAD.DWX exist in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is Brent/GBPCAD, not XTI/GBPCAD, XBR/USDCAD, XBR/AUDCAD, XBR/NZDCAD, XBR/CADJPY, XBR/CADCHF, XBR/XNG, FX-only GBPCAD/GBPNZD cointegration, XAU/XAG, XNG, index, or outright Brent logic."
---

# XBR/GBPCAD D1 Return-Spread Reversion

## Source

- Source: [[sources/EIA-BOC-XBR-GBPCAD-2026]]
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
trades a two-leg relative-value package instead of an outright Brent forecast.

`GBPCAD` rises when CAD weakens against GBP. Because the oil/CAD channel is
inverse in this quote, the implemented dislocation is:

`return_spread = ln(XBR[t] / XBR[t-L]) + beta_gbpcad * ln(GBPCAD[t] / GBPCAD[t-L])`

When Brent has unusually outperformed while GBPCAD has also risen, the package
fades a "oil up while CAD weak" divergence by selling both Brent and GBPCAD. When
Brent has unusually underperformed while GBPCAD has also fallen, it buys both Brent
and GBPCAD.

This is deliberately different from:

- `QM5_13057_xti-gbpcad-rspr`: WTI/GBPCAD, not Brent/GBPCAD.
- `QM5_13005_xbr-cad-rspr`: USDCAD-specific Brent/CAD spread, not GBPCAD.
- `QM5_13079_xbr-audcad-rspr`, `QM5_13082_xbr-nzdcad-rspr`,
  `QM5_13083_xbr-cadjpy-rspr`, and `QM5_13086_xbr-cadchf-rspr`: different CAD
  crosses and different quotation mechanics.
- `QM5_13029_gbpcad-gbpnzd-coint`: FX-only GBPCAD/GBPNZD cointegration, not an
  energy/FX oil-CAD sleeve.
- XAU/XAG, XNG, index, XBR/XNG, oil/metals, and single-symbol Brent
  trend/seasonality sleeves.

## Markets And Timeframe

- Logical symbol: `QM5_13087_XBR_GBPCAD_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`.
- Basket legs: `XBRUSD.DWX` and `GBPCAD.DWX`.
- Period: D1.
- Expected trade frequency: about 6-12 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread metadata, ATR, broker time, and
  V5 framework state only. No EIA, Bank of Canada, futures-curve, inventory,
  CFTC, macro CSV, API, analyst forecast, or ML model is consumed at runtime.

## Entry Rules

- Evaluate only on a new D1 bar of the `XBRUSD.DWX` host chart.
- Copy completed D1 closes for `XBRUSD.DWX` and `GBPCAD.DWX`.
- Compute `xbr_ret = ln(XBR close[1] / XBR close[1 + strategy_return_lookback_d1])`.
- Compute `gbpcad_ret = ln(GBPCAD close[1] / GBPCAD close[1 + strategy_return_lookback_d1])`.
- Compute `return_spread = xbr_ret + strategy_beta_gbpcad * gbpcad_ret`.
- Standardize the latest completed return spread against the prior
  `strategy_z_lookback_d1` completed return spreads.
- Short spread: if z-score is above `strategy_entry_z`, sell `XBRUSD.DWX` and
  sell `GBPCAD.DWX`.
- Long spread: if z-score is below `-strategy_entry_z`, buy `XBRUSD.DWX` and
  buy `GBPCAD.DWX`.
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
- Skip entries when `GBPCAD.DWX` spread exceeds `strategy_gbpcad_max_spread_pts`.
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
- name: strategy_beta_gbpcad
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
- name: strategy_xbr_max_spread_pts
  default: 1200
  sweep_range: [700, 1200, 1500]
- name: strategy_gbpcad_max_spread_pts
  default: 160
  sweep_range: [100, 160, 240]

## Author Claims

The source packet establishes structural lineage for the oil/exchange-rate and
CAD commodity-currency channel only. This card imports no source performance
number. Q02 and later phases must validate or reject the `XBRUSD.DWX` /
`GBPCAD.DWX` basket on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.06.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 6-12 paired packages/year.
- risk_class: medium-high because crude volatility, GBPCAD liquidity, and
  synchronized basket fills need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: U.S. government energy research plus central-bank
  CAD commodity-currency research.
- [x] R2 mechanical: fixed D1 return spread, rolling z-score entry/exit, ATR
  hard stops, spread caps, max-hold exit, and broken-package repair.
- [x] R3 testable: `XBRUSD.DWX` and `GBPCAD.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Non-duplicate: paired Brent/GBPCAD inverse-CAD return-spread mean
  reversion, not Brent/USDCAD, Brent/AUDCAD, Brent/NZDCAD, Brent/CADJPY,
  Brent/CADCHF, WTI/GBPCAD, GBPCAD/GBPNZD cointegration, XBR/XNG,
  metal-ratio, XNG, index, or outright Brent logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Registry And Queue Notes

- Slot 0: `XBRUSD.DWX`.
- Slot 1: `GBPCAD.DWX`.
- Use the logical basket setfile `QM5_13087_XBR_GBPCAD_RSPREAD_D1` for Q02.
- Keep Q02 setfile on `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps, news,
  Friday close, and valid data checks.
- trade_entry: D1 standardized XBR/GBPCAD inverse-CAD return-spread reversion.
- trade_management: broken-package repair and max-hold tracking.
- trade_close: z-score mean exit, max-hold exit, Friday close, and ATR hard
  stops.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce at least one valid logical-basket
trade, if Q02 PF is below 1.0 after costs, if synchronized XBR/GBPCAD history
is insufficient, or if the basket preflight cannot execute both legs under the
V5 one-position-per-magic model.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XBR/GBPCAD return-spread basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PENDING | `artifacts/qm5_13087_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | PENDING | enqueue after compile |
