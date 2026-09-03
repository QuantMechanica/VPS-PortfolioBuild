---
ea_id: QM5_41324
slug: balke-gmt3-range-breakout-path25-opt
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
parent_ea_id: QM5_21501
parent_slug: balke-gmt3-range-breakout-ppcensus
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_21501_balke-gmt3-range-breakout-ppcensus.md
g0_status: APPROVED
g0_authority: "router task 57bc396f-5ac3-4469-aec5-c47d3737b1fd; CEO order 2026-09-03"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: H1
target_symbols: [USDJPY.DWX]
last_updated: 2026-09-03
---

# QM5_41324 `balke-gmt3-range-breakout-path25-opt`

Target symbols: USDJPY.DWX

OWNER-authorized fresh DL-089 measurement sibling of `QM5_21501`. It preserves
the parent's A1-fixed straddle plan, exits, sizing, news, and Friday-close
mechanics and exposes exactly six closed-D1 pattern veto inputs:
`opt_pp_buy1..3` and `opt_pp_sell1..3`. Zero disables a slot, so the shipped
baseline is neutral. No live or pipeline verdict is authorized. Backtests
require `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and
`qm_news_stale_max_hours <= 336`.
