---
ea_id: QM5_12589
slug: eia-rbob-shoulder
type: strategy
source_id: EIA-RBOB-CRACK-SEASON-2025
source_citation: "U.S. Energy Information Administration. Gasoline crack spreads rise ahead of the summer driving season. This Week in Petroleum, 2025-03-12. URL https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php"
sources:
  - "[[sources/EIA-RBOB-CRACK-SEASON-2025]]"
concepts:
  - "[[concepts/gasoline-crack-spread]]"
  - "[[concepts/energy-seasonality]]"
  - "[[concepts/failed-rally]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12589_XTI_RBOB_SHOULDER_D1
period: D1
expected_trade_frequency: "D1 WTI short-only autumn shoulder failed-rally sleeve; estimate 3-7 trades/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA source; R2 PASS deterministic D1 date-window/recent-peak/SMA/trigger/exit rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# EIA RBOB Autumn Shoulder Failed-Rally Short

This build copy mirrors `strategy-seeds/cards/eia-rbob-shoulder_card.md`.
