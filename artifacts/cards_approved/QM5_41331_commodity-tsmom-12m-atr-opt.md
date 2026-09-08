---
ea_id: QM5_41331
slug: commodity-tsmom-12m-atr-opt
type: strategy
source_id: MOP-TSMOM-2012
parent_ea_id: QM5_12710
parent_slug: commodity-tsmom-12m-atr
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_12710_commodity-tsmom-12m-atr.md
g0_status: APPROVED
g0_authority: "router task 262f7959; CEO order 2026-09-03 (OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903)"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
target_symbols: [XTIUSD.DWX]
expected_trades_per_year_per_symbol: 7
last_updated: 2026-09-03
---

# QM5_41331 `commodity-tsmom-12m-atr-opt`

Target symbols: XTIUSD.DWX

OWNER-authorized DL-089 measurement sibling of `QM5_12710`. It preserves the
recompiled parent entry, exit, sizing, news, and Friday-close mechanics and adds
exactly six closed-D1 pattern veto inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`.
Zero disables a slot, so the shipped baseline is neutral. No live or pipeline
verdict is authorized. Backtests require `RISK_FIXED > 0`, `RISK_PERCENT = 0`,
and `qm_news_stale_max_hours <= 336`.

## R1-R4 assessment

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Inherited from the approved QM5_12710 parent card and its named source (MOP-TSMOM-2012). |
| R2 Mechanical | PASS | Parent mechanics are unchanged; the six deterministic inputs only veto entries. |
| R3 Data Available | PASS | Uses closed D1 OHLC predicates on XTIUSD.DWX, alongside the parent's D1 momentum/ATR inputs. |
| R4 No ML | PASS | Fixed deterministic rules; no ML, grid, martingale, or online adaptation. |
