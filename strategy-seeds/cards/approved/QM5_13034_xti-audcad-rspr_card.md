---
ea_id: QM5_13034
slug: xti-audcad-rspr
type: strategy
strategy_id: EIA-RBA-BOC-XTI-AUDCAD-2026_S01
source_id: EIA-RBA-BOC-XTI-AUDCAD-2026
source_citation: "EIA oil/exchange-rate working paper plus official RBA commodity-AUD and Bank of Canada oil-CAD context."
source_citations:
  - type: government_research
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: primary
  - type: central_bank_explainer
    citation: "Reserve Bank of Australia. Drivers of the Australian Dollar Exchange Rate."
    location: "https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html"
    quality_tier: A
    role: aud_channel
  - type: central_bank_report
    citation: "Bank of Canada. Monetary Policy Report April 2026, Canadian outlook."
    location: "https://www.bankofcanada.ca/publications/mpr/mpr-2026-04-29/canadian-outlook/"
    quality_tier: A
    role: cad_oil_channel
sources:
  - "[[sources/EIA-RBA-BOC-XTI-AUDCAD-2026]]"
concepts:
  - "[[concepts/oil-exchange-rate-linkage]]"
  - "[[concepts/commodity-fx-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/rolling-return-spread]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, AUDCAD.DWX]
basket_symbols: [XTIUSD.DWX, AUDCAD.DWX]
markets: [XTIUSD.DWX, AUDCAD.DWX]
primary_target_symbols: [XTIUSD.DWX, AUDCAD.DWX]
single_symbol_only: false
logical_symbol: QM5_13034_XTI_AUDCAD_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XTI/AUDCAD return-spread z-score reversion; estimate 6-12 paired packages/year before Q02 validates synchronized history and fills."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-07: R1 PASS official EIA/RBA/BoC source packet; R2 PASS deterministic D1 two-leg XTI/AUDCAD return-spread z-score reversion with spread caps, mean exit, max-hold exit, and ATR hard stops; R3 PASS XTIUSD.DWX and AUDCAD.DWX exist in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because this is WTI versus CAD-through-AUDCAD relative value, not XTI/AUDUSD breakout, XTI/NZD, XTI/CADJPY, XTI/CADCHF, WTI/USDCAD, XTI/XNG, Brent/WTI, oil-metal, XNG, XAU/XAG, calendar, WPSR, COT, or RSI commodity logic."
---

# XTI/AUDCAD D1 Return-Spread Reversion

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-audcad-rspr_card.md`.

The EA trades a D1 two-leg basket on `XTIUSD.DWX` and `AUDCAD.DWX`. It computes
`XTI_return + beta_audcad * AUDCAD_return`, enters at z-score extremes, and
exits on z-score reversion, max-hold, Friday close, broken-package repair, or
per-leg ATR hard stops.

This is not an XTI/AUDUSD breakout, XTI/NZD, XTI/CADJPY, XTI/CADCHF,
WTI/USDCAD, XTI/XNG, WTI/Brent, oil-metal, calendar/event, COT, or RSI
commodity sleeve. Backtests use `RISK_FIXED=1000`, no external runtime data,
no ML, no grid, no martingale, and no live/deploy manifest changes.

Q01 build validation passed on 2026-07-07. Q02 is pending as
`work_items:25b8585f-91bd-43d4-bb98-32480bbe89bf` for logical basket
`QM5_13034_XTI_AUDCAD_RSPREAD_D1`.
