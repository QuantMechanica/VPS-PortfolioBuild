---
copy_of: strategy-seeds/cards/approved/QM5_20278_wti-linw-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_LINW12_S26
variant_id: MOP-TSMOM-2012_XTI_LINW12_S26
source_id: MOP-WTI-LINW-2026
ea_id: QM5_20278
slug: wti-linw-mom
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-one-through-twelve-linear-recency-weighted-completed-monthly-log-returns
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q02_ENQUEUED
q01_status: PASS
q02_status: ENQUEUED
last_updated: 2026-08-11
---

# QM5_20278 WTI Linear-Recency Return Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20278_wti-linw-mom_card.md`.

## Hypothesis

A fixed oldest-to-newest weight vector `1..12` over twelve disjoint completed
monthly WTI returns may respond to a slow oil regime while retaining a full
year of history. This is a direct crude-oil structural carrier, not a
profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes and form twelve chronological adjacent
log returns. Multiply return index `i` by `i+1`, sum all twelve terms, and
divide by exactly 78. Buy when positive, sell when negative, and consume
exact-zero or invalid states flat. Renew at the next month boundary. The
canonical card locks chronology, every weight, divisor, persisted attempt,
ATR stop, spread cap, and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is APPROVED and Q01 is PASS. One current-binary `XTIUSD.DWX` Q02 row is
pending as work item `50b53e15-f54e-407d-89ee-76dfc758f762`; no screening
verdict is claimed.
