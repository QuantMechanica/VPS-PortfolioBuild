---
ea_id: QM5_41478
slug: grimes-complex-pb-opt
type: strategy
source_id: fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
parent_ea_id: QM5_10911
parent_slug: grimes-complex-pb
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_10911_grimes-complex-pb.md
g0_status: DRAFT
g0_pending: "OWNER seal required. Commissioned per docs/ops/evidence/2026-09-16_dl089_matrix_service_q12_queue_disposition.md (recommended unblock sequence #1). R1-R4 assessments below are staged for OWNER ratification, not self-approved. See docs/ops/evidence/2026-09-16_opt_sibling_10911/RECEIPT.md."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: H1
target_symbols: [GDAXI.DWX]
expected_trades_per_year_per_symbol: 30
last_updated: 2026-09-16
---

# QM5_41478 `grimes-complex-pb-opt`

> **DRAFT — PENDING OWNER SEAL.** House format mirrors the approved Amendment C
> sibling cards (e.g. QM5_41347). The governed card-of-record at
> `framework/EAs/QM5_41478_grimes-complex-pb-opt/docs/strategy_card.md` is
> created by `governed_magic_allocator.py` from the APPROVED card in
> `D:/QM/strategy_farm/artifacts/cards_approved/`; `g0_status: APPROVED` plus a
> real `g0_authority` citation is recorded by OWNER only
> (`processes/01-ea-lifecycle.md`, `processes/13-strategy-research.md`).
> On approval, copy this file to
> `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41478_grimes-complex-pb-opt.md`,
> set `g0_status: APPROVED`, and fill `g0_authority`.

Target symbol: `GDAXI.DWX`.

OWNER-authorized-pending DL-089 measurement sibling of `QM5_10911`. It preserves
the parent entry, exit, sizing, news, and Friday-close mechanics and adds exactly
six closed-D1 pattern-veto inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`.
Zero disables a slot, so the shipped baseline is neutral. No live or pipeline
verdict is authorized. Backtests require `RISK_FIXED > 0`, `RISK_PERCENT = 0`,
and `qm_news_stale_max_hours <= 336`.

## R1-R4 assessment (staged for OWNER ratification)

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Inherited from the approved QM5_10911 parent card (`fbfd7f6e-…`) and its named Grimes sources. |
| R2 Mechanical | PASS | Parent mechanics unchanged; the six deterministic closed-D1 inputs only veto entries (`Pattern_AllowsRequest` gates the sole order consumer). |
| R3 Data Available | PASS | Closed-D1 OHLC predicates on GDAXI.DWX alongside the parent's H1 inputs. |
| R4 No ML | PASS | Fixed deterministic rules; no ML, grid, martingale, or online adaptation. |

## Staged engineering artifacts (validation evidence in RECEIPT.md)

- Source: `staged/QM5_41478_grimes-complex-pb-opt.mq5` — derived from the
  parent by the 7-hunk verified sibling transformation
  (`derive_sibling_source.py`); passes `_pattern_measurement_readiness`
  (ready=True, zero blockers) against the canonical service code.
- Base setfile: `staged/QM5_41478_grimes-complex-pb-opt_GDAXI.DWX_H1_backtest.set`
  — parent's GDAXI parameterization + `qm_ea_id=41478` + six neutral `opt_pp_*`;
  passes `_neutral_matrix_setfile` and `census.validate_base_setfile`.
