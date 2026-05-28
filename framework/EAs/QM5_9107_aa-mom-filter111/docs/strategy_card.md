---
ea_id: QM5_9107
slug: aa-mom-filter111
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/turnover-control]]"
indicators:
  - "[[indicators/rate-of-change]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: UNKNOWN
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS Alpha Architect URL; R2 PASS deterministic 11-1 and 10-0 momentum rank entry/exit; R3 PASS price-only cross-sectional rule portable to DWX FX/index/commodity basket; R4 PASS fixed non-ML 1-pos rules."
---

# Alpha Architect Filtered 11-1 Momentum

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Larry Swedroe, "Enhancing Momentum Strategies", 2025-06-13, https://alphaarchitect.com/momentum-investing/

## Mechanik

The article summarizes Calluzzo, Moneta, and Topaloglu's long-holding-period momentum work. The draft uses their concentrated filter idea: form a normal momentum bucket, but exclude instruments that are already forecast to leave the bucket at the next rebalance based on partially known future ranking windows.

### Entry
- Evaluate on the final completed monthly bar.
- Universe: approved stock, sector, index, FX, or multi-asset proxy basket.
- Compute `MOM_11_1 = Close(1) / Close(12) - 1`.
- Compute next-window proxy rank using `MOM_10_0 = Close(0) / Close(10) - 1`.
- Select instruments in the top decile by `MOM_11_1`.
- Exclude selected instruments whose `MOM_10_0` rank is outside the top decile.
- Long remaining instruments equal-weighted.
- Optional P2 long/short mode: short bottom decile passing the symmetric bottom-decile persistence filter.

### Exit
- Rebalance monthly or quarterly per P3 variant.
- Close any long no longer passing both current and next-window momentum filters.
- Close shorts no longer passing symmetric bottom-bucket filters.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1) per leg.
- Time stop: next scheduled rebalance.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000`, equal risk per active slot.
- T6-live: `RISK_PERCENT = 0.5` aggregate portfolio risk.

### Zusätzliche Filter
- One position per symbol/magic.
- Minimum 24 monthly bars.
- Skip entries when D1 spread exceeds 2.5 x 20-day median spread.

## Concepts (was ist das für eine Strategie)
- [[concepts/cross-sectional-momentum]] - primary
- [[concepts/turnover-control]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Larry Swedroe and publication date. |
| R2 Mechanical | PASS | Fixed current and forward-known momentum rank filters with deterministic rebalance logic. |
| R3 Data Available | UNKNOWN | Price-only rule is portable to DWX baskets, but source is stock-universe based and needs approved proxy universe size. |
| R4 ML Forbidden | PASS | Uses only fixed rank windows; no ML, adaptive parameters, grid, or martingale. |

## R3
Best initial port is a cross-sectional DWX index/FX/commodity basket if the reviewer accepts a non-stock proxy. SP500.DWX alone is insufficient because the rule is cross-sectional.

## Pipeline-Verlauf
- G0: PENDING (Batch 14 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1642_aa-xasset-xmom-third]] - related cross-sectional momentum.
- [[strategies/QM5_1604_aa-mom-ex3-filter]] - related filtered momentum construction.

## Lessons Learned (während Pipeline-Lauf)
- TBD
