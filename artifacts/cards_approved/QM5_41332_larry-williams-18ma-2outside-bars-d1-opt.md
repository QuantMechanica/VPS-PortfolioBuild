---
ea_id: QM5_41332
slug: larry-williams-18ma-2outside-bars-d1-opt
type: strategy
source_id: c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9
parent_ea_id: QM5_11910
parent_slug: larry-williams-18ma-2outside-bars-d1
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11910_larry-williams-18ma-2outside-bars-d1.md
g0_status: APPROVED
g0_authority: "router task 262f7959; CEO order 2026-09-03 (sibling wave 3, path-to-25)"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
target_symbols: [NZDUSD.DWX]
expected_trades_per_year_per_symbol: 15
last_updated: 2026-09-03
---

# QM5_41332 `larry-williams-18ma-2outside-bars-d1-opt`

Target symbols: NZDUSD.DWX

OWNER-authorized DL-089 measurement sibling of `QM5_11910`. It preserves the
parent entry, exit, sizing, news, and Friday-close mechanics and adds exactly
six closed-D1 pattern veto inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`.
Zero disables a slot, so the shipped baseline is neutral. No live or pipeline
verdict is authorized. Backtests require `RISK_FIXED > 0`, `RISK_PERCENT = 0`,
and `qm_news_stale_max_hours <= 336`.

## R1-R4 assessment

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Inherited from the approved QM5_11910 parent card and its named source. |
| R2 Mechanical | PASS | Parent mechanics are unchanged; the six deterministic inputs only veto entries. |
| R3 Data Available | PASS | Uses closed D1 OHLC predicates on NZDUSD.DWX, alongside the parent's D1 inputs. |
| R4 No ML | PASS | Fixed deterministic rules; no ML, grid, martingale, or online adaptation. |
