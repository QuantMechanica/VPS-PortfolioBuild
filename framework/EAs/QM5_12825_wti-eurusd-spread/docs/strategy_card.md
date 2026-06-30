---
ea_id: QM5_12825
slug: wti-eurusd-spread
type: strategy
source_id: EIA-OIL-USD-FX-2017
source_citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017. URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
source_citations:
  - type: working_paper
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. (2017). The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration."
    location: "EIA working paper PDF"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-OIL-USD-FX-2017]]"
concepts:
  - "[[concepts/oil-dollar-linkage]]"
  - "[[concepts/commodity-fx-relative-value]]"
  - "[[concepts/spread-mean-reversion]]"
indicators:
  - "[[indicators/log-spread-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, spread-mean-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, EURUSD.DWX]
basket_symbols: [XTIUSD.DWX, EURUSD.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 z-score gate on a 120-day XTIUSD/EURUSD log spread; estimate 7 entries per year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS single official EIA working paper on oil prices and exchange rates; R2 PASS deterministic D1 XTIUSD/EURUSD log-spread z-score entries, z-score/time exits, ATR stops; R3 PASS DWX XTIUSD/EURUSD symbols; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 24.0
---

# WTI EURUSD Spread Mean Reversion

The canonical strategy card for this EA is stored at
`strategy-seeds/cards/approved/QM5_12825_wti-eurusd-spread_card.md` and mirrored
in `artifacts/cards_approved/QM5_12825_wti-eurusd-spread_card.md` for the farm
queue.
