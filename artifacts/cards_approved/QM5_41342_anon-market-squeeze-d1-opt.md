---
ea_id: QM5_41342
slug: anon-market-squeeze-d1-opt
type: strategy
source_id: 91733bcd-fc55-59be-a119-de42fd753c3c
parent_ea_id: QM5_11708
parent_slug: anon-market-squeeze-d1
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11708_anon-market-squeeze-d1.md
g0_status: APPROVED
g0_authority: "router task db42cb90-ce73-4126-aa97-862bdb0438af; Amendment C measurement-sibling build 2026-09-05"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
target_symbols: [EURUSD.DWX]
expected_trades_per_year_per_symbol: 30
last_updated: 2026-09-05
---

# QM5_41342 `anon-market-squeeze-d1-opt`

Target symbol: `EURUSD.DWX`.

OWNER-authorized DL-089 measurement sibling of `QM5_11708`. It preserves the
parent entry, exit, sizing, news, and Friday-close mechanics and adds exactly
six closed-D1 pattern-veto inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`.
Zero disables a slot, so the shipped baseline is neutral. No live or pipeline
verdict is authorized. Backtests require `RISK_FIXED > 0`, `RISK_PERCENT = 0`,
and `qm_news_stale_max_hours <= 336`.

## R1-R4 assessment

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Inherited from the approved QM5_11708 parent and source `91733bcd-fc55-59be-a119-de42fd753c3c`. |
| R2 Mechanical | PASS | Parent mechanics are unchanged; six deterministic inputs only veto entries. |
| R3 Data Available | PASS | Uses closed D1 OHLC predicates on `EURUSD.DWX` with the parent's native inputs. |
| R4 No ML | PASS | Fixed deterministic rules; no ML, grid, martingale, or online adaptation. |

