---
ea_id: QM5_12727
slug: wti-apr-prem
type: strategy
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Chovancova, B. and Balaz, V. Seasonal patterns in oil prices and their implications for investors. Journal of Investment Strategies. URL https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
sources:
  - "[[sources/ARENDAS-OIL-SEASON-2018]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "April-only D1 WTI month-of-year positive-return sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS academic oil-seasonality paper; R2 PASS deterministic April D1 long/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
---

# WTI April Calendar Premium

Local build copy of APPROVED card
`strategy-seeds/cards/approved/QM5_12727_wti-apr-prem_card.md`.
