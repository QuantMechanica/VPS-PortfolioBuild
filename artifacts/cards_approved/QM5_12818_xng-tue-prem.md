---
ea_id: QM5_12818
slug: xng-tue-prem
type: strategy
source_id: MEEK-HOELSCHER-XNG-DOW-2023
source_citation: "Meek, H. and Hoelscher, S. A. Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2023. DOI https://doi.org/10.1080/23322039.2023.2213876; open pointer https://www.econstor.eu/handle/10419/304091"
sources:
  - "[[sources/MEEK-HOELSCHER-XNG-DOW-2023]]"
concepts:
  - "[[concepts/natural-gas-day-of-week-seasonality]]"
  - "[[concepts/tuesday-calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12818_XNG_TUE_PREM_D1
period: D1
expected_trade_frequency: "Weekly D1 natural-gas Tuesday-calendar premium sleeve; estimate 45-52 trades/year after broker holidays and framework filters."
expected_trades_per_year_per_symbol: 48
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
expected_pf: 1.08
expected_dd_pct: 23.0
g0_approval_reasoning: "R1 PASS peer-reviewed petroleum and natural-gas day-of-week source; R2 PASS deterministic Tuesday D1 long/next-bar flat rule with ATR stop; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# XNG Tuesday Calendar Premium

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12818_xng-tue-prem_card.md`.

Summary: D1 `XNGUSD.DWX` Tuesday calendar-premium sleeve from the
peer-reviewed petroleum and Natural Gas day-of-week source. It buys only the
broker-calendar Tuesday D1 bar, uses a fixed ATR hard stop, and exits on the
next non-Tuesday D1 bar or max-hold stale guard. Runtime uses Darwinex OHLC,
broker calendar, spread, and ATR only.

Q02 queue: `work_items/44fd14be-d7de-4752-9e59-82e0fc49798a`.
