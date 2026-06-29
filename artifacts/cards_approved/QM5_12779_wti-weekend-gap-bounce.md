---
ea_id: QM5_12779
slug: wti-weekend-gap-bounce
type: strategy
source_id: TGIF-WTI-WEEKEND-2017
source_citation: "TGIF? The weekend effect in energy commodities. Journal of Finance Issues. URL https://jfi-aof.org/index.php/jfi/article/view/2264"
sources:
  - "[[sources/TGIF-WTI-WEEKEND-2017]]"
concepts:
  - "[[concepts/crude-oil-weekend-effect]]"
  - "[[concepts/weekend-gap-fill]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, weekend-gap, gap-fill, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 WTI negative-weekend-gap bounce; estimate 6-16 trades/year after Monday/friday-contiguity, gap-size, spread, and framework filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS academic energy-weekend-effect source; R2 PASS deterministic Monday negative-gap long with ATR stop, gap-fill TP, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 17.0
---

# WTI Weekend Gap Bounce

See canonical approved card:
`strategy-seeds/cards/approved/QM5_12779_wti-weekend-gap-bounce_card.md`.
