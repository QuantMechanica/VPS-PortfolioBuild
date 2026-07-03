---
ea_id: QM5_12988
slug: xti-eia-inventory-momentum
type: strategy
source_id: EIA-WPSR-2W-MOM-2026
sources:
  - "U.S. Energy Information Administration, Weekly Petroleum Status Report, https://www.eia.gov/petroleum/supply/weekly/"
  - "U.S. Energy Information Administration, Weekly Petroleum Status Report schedule, https://www.eia.gov/petroleum/supply/weekly/schedule.php"
  - "U.S. Energy Information Administration, Oil and petroleum products explained, https://www.eia.gov/energyexplained/oil-and-petroleum-products/"
concepts:
  - "crude-oil-inventory-information-cycle"
  - "multiweek-post-event-momentum"
  - "breakout-confirmation"
indicators:
  - "SMA"
  - "ATR"
  - "Donchian breakout"
strategy_type_flags: [inventory-event, structural-demand, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12988_XTI_WPSR_2W_MOM_D1
period: D1
expected_trade_frequency: "D1 WTI two-event WPSR reaction momentum; estimate 5-12 trades/year after two-event, breakout, trend, and spread filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.12
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA WPSR/release schedule and petroleum-market structure pages; R2 PASS deterministic D1 two-event reaction momentum with SMA trend gate, Donchian confirmation, ATR stop, and time/trend exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# XTI EIA Inventory Momentum

See `strategy-seeds/cards/approved/QM5_12988_xti-eia-inventory-momentum_card.md`
for the canonical approved strategy card.

