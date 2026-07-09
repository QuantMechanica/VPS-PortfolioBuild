---
ea_id: QM5_13079
slug: xbr-audcad-rspr
type: strategy
strategy_id: EIA-RBA-BOC-XBR-AUDCAD-2026
source_id: EIA-RBA-BOC-XBR-AUDCAD-2026
source_citation: "EIA oil/exchange-rate working paper plus official RBA commodity-AUD and Bank of Canada commodity-CAD context."
source_citations:
  - type: government_research
    citation: "Beckmann, Czudaj, and Arora. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, 2017."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_explainer
    citation: "Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate."
    location: "https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
    quality_tier: A
    role: aud_channel
  - type: central_bank_research
    citation: "Bank of Canada Staff Analytical Note 2017-1. The Share of Systematic Variations in the Canadian Dollar - Part II."
    location: "https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/"
    quality_tier: A
    role: cad_channel
sources:
  - "[[sources/EIA-RBA-BOC-XBR-AUDCAD-2026]]"
concepts:
  - "[[concepts/oil-fx-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/energy-sleeve]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [brent-fx-return-spread, market-neutral-basket, zscore-reversion, atr-hard-stop, time-stop, low-frequency, energy]
target_symbols: [XBRUSD.DWX, AUDCAD.DWX]
basket_symbols: [XBRUSD.DWX, AUDCAD.DWX]
markets: [XBRUSD.DWX, AUDCAD.DWX]
primary_target_symbols: [XBRUSD.DWX, AUDCAD.DWX]
single_symbol_only: false
logical_symbol: QM5_13079_XBR_AUDCAD_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XBR/AUDCAD return-spread z-score reversion; estimate 7-12 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 9
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS official EIA oil/exchange-rate research plus RBA AUD exchange-rate support and Bank of Canada commodity-CAD support; R2 PASS deterministic D1 two-leg XBR/AUDCAD return-spread z-score reversion with spread caps, mean exit, max-hold exit, and ATR hard stops; R3 PASS XBRUSD.DWX and AUDCAD.DWX are existing framework symbols; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is a Brent/AUDCAD commodity-FX basket, not XTI/AUDCAD, XBR/USDCAD, XBR/XNG, Brent calendar/seasonality, WTI/USDCAD, WTI/AUDUSD, XTI/XNG, metal-ratio, XNG, index, or commodity-RSI logic."
---

# XBR/AUDCAD D1 Return-Spread Reversion

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xbr-audcad-rspr_card.md`.

The EA trades a D1 two-leg basket on `XBRUSD.DWX` and `AUDCAD.DWX`. It computes
`XBR_return + beta_audcad * AUDCAD_return`, enters at z-score extremes, and
exits on z-score reversion, max-hold, Friday close, broken-package repair, or
per-leg ATR hard stops.

This is not XTI/AUDCAD, XBR/USDCAD, XBR/XNG, Brent calendar/seasonality,
WTI/USDCAD, WTI/AUDUSD, XTI/XNG, XAU/XAG, XNG, index, or commodity-RSI logic.
Backtests use `RISK_FIXED=1000`, no external runtime data, no ML, no grid, no
martingale, and no live/deploy manifest changes.

Q01 build validation is pending on 2026-07-09. Q02 will use logical basket
`QM5_13079_XBR_AUDCAD_RSPREAD_D1`.
