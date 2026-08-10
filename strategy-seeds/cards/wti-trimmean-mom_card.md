---
copy_of: strategy-seeds/cards/approved/QM5_20270_wti-trimmean-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_TRIM12_S19
variant_id: MOP-TSMOM-2012_XTI_TRIM12_S19
source_id: MOP-WTI-TRIMMEAN-2026
ea_id: QM5_20270
slug: wti-trimmean-mom
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-middle-eight-trimmed-mean-of-twelve-disjoint-completed-monthly-log-returns
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_STARTED
last_updated: 2026-08-10
---

# QM5_20270 WTI Trimmed-Mean Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20270_wti-trimmean-mom_card.md`.

## Hypothesis

The mean of the middle eight among twelve disjoint completed monthly WTI
returns may capture a broad slow oil direction without letting the two most
extreme observations in either tail dominate. This is a direct crude-oil
structural carrier, not a profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes, form twelve disjoint log returns, sort
them, delete ascending indexes 0, 1, 10, and 11, and average indexes 2 through
9 with divisor eight. Buy for a positive trimmed mean, sell for a negative
trimmed mean, and consume an exact-zero or invalid month flat. Renew at the
next month boundary. The canonical card locks endpoints, deletion indexes,
divisor, sides, persisted attempt, ATR stop, spread cap, and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Deterministic
allocation and build/Q01 are PASS; paced Q02 handoff remains pending.
