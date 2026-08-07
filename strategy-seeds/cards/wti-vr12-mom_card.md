---
copy_of: strategy-seeds/cards/approved/QM5_20257_wti-vr12-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MEHLITZ-AUER-MEM-2024_XTI_R12Q13_S04
variant_id: MEHLITZ-AUER-MEM-2024_XTI_R12Q13_S04
source_id: MEHLITZ-AUER-WTI-R12Q13-2026
ea_id: QM5_20257
slug: wti-vr12-mom
status: APPROVED
g0_status: APPROVED
source_author: "Julia S. Mehlitz; Benjamin R. Auer"
strategy_mechanic: monthly-wti-twelve-month-return-sign-times-q13-heteroskedastic-robust-variance-ratio-memory-state
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
last_updated: 2026-08-07
---

# QM5_20257 WTI R12-q13 Memory-Enhanced Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20257_wti-vr12-mom_card.md`.

## Hypothesis

Take monthly WTI exposure only when the source-matched twelve-month return and
`q=13` robust variance-ratio state define a significant continuation or
reversal direction.

## Rules

The canonical card locks 33 month ends, 32 monthly returns, the twelve-month
ranking return, twelve `q=13` lags and weights, the two-sided 10% critical value,
one attempt per month, a frozen ATR hard stop, monthly rollover, and stale exit.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live artifact or portfolio mutation is authorized.
