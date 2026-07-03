---
ea_id: QM5_12981
slug: brent-febsep-prem
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_BRENT_FEBSEP_S01
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Tkacova, D. and Bukoven, J. Seasonal patterns in oil prices and their implications for investors. Journal of International Studies, 11(2), 180-192. DOI 10.14254/2071-8330.2018/11-2/12."
source_citations:
  - type: paper
    citation: "Arendas, P., Tkacova, D. and Bukoven, J. (2018). Seasonal patterns in oil prices and their implications for investors. Journal of International Studies, 11(2), 180-192. DOI 10.14254/2071-8330.2018/11-2/12."
    location: "https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/ARENDAS-OIL-SEASON-2018]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "First tradable D1 bar of February through September on Brent; estimate 8 entries/year before framework filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS peer-reviewed oil-seasonality paper covering Brent and WTI; R2 PASS deterministic February-September Brent source-window rule, first-trading-day entry, next-D1-bar exit, and ATR hard stop; R3 PASS XBRUSD.DWX local Brent route; R4 PASS no ML/grid/martingale/external data. Non-duplicate versus existing commodity sleeves because this is a low-frequency Brent seasonal source-window sleeve, not a single Brent month, WTI event/calendar, XTI/XNG, XNG, XAU/XAG, gas-metal, trend, carry, or commodity RSI rule."
expected_pf: 1.05
expected_dd_pct: 14.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
---

# Brent February-September Seasonal Premium

Approved build copy of `strategy-seeds/cards/brent-febsep-prem_card.md`.

Runtime is restricted to `XBRUSD.DWX` D1 OHLC, broker calendar, spread, ATR, and
V5 framework state. No external EIA feed, futures curve, inventory data, CSV,
API, analyst forecast, ML, grid, martingale, or live-deploy artifact is used.

## Rules

- Enter long only on the first tradable D1 bar of February through September.
- Exit on the next D1 bar, outside the source window, max-hold expiry, Friday
  close, or ATR hard stop.
- Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for Q02
  backtests.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial Brent February-September seasonal build | Q02 | PENDING |
