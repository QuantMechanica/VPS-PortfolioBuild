---
ea_id: QM5_12894
slug: xng-mar-transseason-short
type: strategy
strategy_id: EIA-XNG-SHOULDER-2026_S04
source_id: EIA-XNG-SHOULDER-2026
source_citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
strategy_type_flags: [calendar-seasonality, structural-demand, shoulder-season-demand, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
logical_symbol: QM5_12894_XNG_MAR_TRANSSEASON_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency March-to-mid-April natural-gas transseason short sleeve; weekly entry cadence, about 5-8 trade attempts/year before Q02 validates fill history."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.05
expected_dd_pct: 20.0
risk_class: high
ml_required: false
g0_approval_reasoning: "R1 PASS official EIA natural-gas seasonality source; R2 PASS deterministic Mar 1-Apr 15 weekly short rule using transition-rebound, downside-drift, SMA-stretch, ATR stop, time/season exits; R3 PASS XNGUSD.DWX exists in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XNG March Transseason Short

G0-approved mission-directed copy of
`strategy-seeds/cards/approved/QM5_12894_xng-mar-transseason-short_card.md`.

Build evidence: `artifacts/qm5_12894_build_result.json`.
Q02 enqueue evidence: `artifacts/qm5_12894_q02_enqueue_20260708.json`.
