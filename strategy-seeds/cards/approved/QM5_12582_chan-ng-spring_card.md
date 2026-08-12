---
ea_id: QM5_12582
slug: chan-ng-spring
type: strategy
source_id: SRC02
source_citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. Sidebar p. 150, natural gas June-expiry seasonal trade."
sources:
  - "[[sources/SRC02]]"
concepts:
  - "[[concepts/annual-calendar-trade]]"
  - "[[concepts/natural-gas-seasonality]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_12582_XNG_SPRING_D1
period: D1
expected_trade_frequency: "Annual natural-gas spring calendar window; with V5 Friday-close segmentation, estimate 5-8 D1 entries/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS Chan/Wiley source and prior SRC02 OWNER ratification; R2 PASS deterministic annual date window with SMA/ATR rules; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.10
expected_dd_pct: 20.0
---

# Chan Natural Gas Spring Calendar

See `strategy-seeds/cards/chan-ng-spring_card.md` for the working card body.
