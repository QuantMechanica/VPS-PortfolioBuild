---
copy_of: strategy-seeds/cards/approved/QM5_20269_wti-medret-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_MEDRET12_S18
variant_id: MOP-TSMOM-2012_XTI_MEDRET12_S18
source_id: MOP-WTI-MEDRET-2026
ea_id: QM5_20269
slug: wti-medret-mom
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-even-sample-median-of-twelve-disjoint-completed-monthly-log-returns
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
last_updated: 2026-08-09
---

# QM5_20269 WTI Median-Return Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20269_wti-medret-mom_card.md`.

## Hypothesis

The median of twelve disjoint completed monthly WTI returns may capture the
typical direction of a slow oil regime without letting one shock dominate the
signal. This is a direct crude-oil structural carrier, not a profitability or
decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes, form twelve disjoint log returns, sort
them, and average zero-based indexes 5 and 6. Buy for a positive median, sell
for a negative median, and consume an exact-zero or invalid month flat. Renew
at the next month boundary. The canonical card locks endpoints, median
indexes, sides, persisted attempt, ATR stop, spread cap, and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Deterministic
allocation, build/Q01, and paced Q02 handoff remain pending.
