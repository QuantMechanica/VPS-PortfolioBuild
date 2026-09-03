---
ea_id: QM5_41323
slug: pp-wedge-opt
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
parent_ea_id: QM5_11660
parent_slug: pp-wedge
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11660_pp-wedge.md
g0_status: APPROVED
g0_authority: "router task 57bc396f-5ac3-4469-aec5-c47d3737b1fd; CEO order 2026-09-03"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: H4
target_symbols: [NDX.DWX]
last_updated: 2026-09-03
---

# QM5_41323 `pp-wedge-opt`

Target symbols: NDX.DWX

OWNER-authorized DL-089 measurement sibling of `QM5_11660`. It preserves the
parent entry, exit, sizing, news, and Friday-close mechanics for the declared
carrier and adds exactly six closed-D1 pattern veto inputs: `opt_pp_buy1..3`
and `opt_pp_sell1..3`. Zero disables a slot, so the shipped baseline is neutral.
No live or pipeline verdict is authorized. Backtests require `RISK_FIXED > 0`,
`RISK_PERCENT = 0`, and `qm_news_stale_max_hours <= 336`.
