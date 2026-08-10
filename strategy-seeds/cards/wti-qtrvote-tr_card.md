---
copy_of: strategy-seeds/cards/approved/QM5_20272_wti-qtrvote-tr_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_QTRVOTE12_S21
variant_id: MOP-TSMOM-2012_XTI_QTRVOTE12_S21
source_id: MOP-WTI-QTRVOTE-2026
ea_id: QM5_20272
slug: wti-qtrvote-tr
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-four-nonoverlapping-quarter-return-three-of-four-sign-consensus
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
last_updated: 2026-08-10
---

# QM5_20272 WTI Quarterly-Block Consensus Trend

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20272_wti-qtrvote-tr_card.md`.

## Hypothesis

A WTI direction present in at least three of four non-overlapping quarterly
blocks may represent a more persistent prior-year oil regime than a single
cumulative endpoint move. This is a direct crude-oil structural carrier, not a
profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes. Form log returns over exact boundary
pairs `(0,3)`, `(3,6)`, `(6,9)`, and `(9,12)`. Buy when at least three are
strictly positive, sell when at least three are strictly negative, and consume
all other states flat. Exact-zero blocks are neutral. Renew at the next month
boundary. The canonical card locks endpoints, block boundaries, log
orientation, vote threshold, sides, persisted attempt, ATR stop, spread cap,
and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Deterministic
allocation, build/Q01, and Q02 enqueue have not yet run.
