---
copy_of: strategy-seeds/cards/approved/QM5_20256_wti-vr6-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MEHLITZ-AUER-MEM-2024_XTI_R6Q7_S03
variant_id: MEHLITZ-AUER-MEM-2024_XTI_R6Q7_S03
source_id: MEHLITZ-AUER-WTI-R6Q7-2026
ea_id: QM5_20256
slug: wti-vr6-mom
status: APPROVED
g0_status: APPROVED
source_author: "Julia S. Mehlitz; Benjamin R. Auer"
strategy_mechanic: monthly-wti-six-month-return-sign-times-q7-heteroskedastic-robust-variance-ratio-memory-state
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: "8d734be9-bd6e-4626-990a-1a75b3e27fa3"
last_updated: 2026-08-07
---

# QM5_20256 WTI R6-q7 Memory-Enhanced Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20256_wti-vr6-mom_card.md`.

## Hypothesis

Take monthly WTI exposure only when the source-matched six-month return and
`q=7` robust variance-ratio state define a significant continuation or
reversal direction.

## Rules

The canonical card locks 33 month ends, 32 monthly returns, the six-month
ranking return, six `q=7` lags and weights, the two-sided 10% critical value,
one attempt per month, a frozen ATR hard stop, monthly rollover, and stale exit.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live artifact or portfolio mutation is authorized.
