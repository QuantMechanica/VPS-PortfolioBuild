---
ea_id: QM5_41322
slug: et-turtle20x-opt
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
parent_ea_id: QM5_10403
parent_slug: et-turtle20x
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_10403_et-turtle20x.md
g0_status: APPROVED
g0_authority: "router task 57bc396f-5ac3-4469-aec5-c47d3737b1fd; CEO order 2026-09-03"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
target_symbols: [XAUUSD.DWX]
last_updated: 2026-09-03
---

# QM5_41322 `et-turtle20x-opt`

Target symbols: XAUUSD.DWX

OWNER-authorized DL-089 measurement sibling of `QM5_10403`. It preserves the
parent entry, exit, sizing, news, and Friday-close mechanics and adds exactly
six closed-D1 pattern veto inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`.
Zero disables a slot, so the shipped baseline is neutral. No live or pipeline
verdict is authorized. Backtests require `RISK_FIXED > 0`, `RISK_PERCENT = 0`,
and `qm_news_stale_max_hours <= 336`.
