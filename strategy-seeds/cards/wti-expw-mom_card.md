---
copy_of: strategy-seeds/cards/approved/QM5_20279_wti-expw-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_EXPW12_S27
variant_id: MOP-TSMOM-2012_XTI_EXPW12_S27
source_id: MOP-WTI-EXPW-2026
ea_id: QM5_20279
slug: wti-expw-mom
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-twelve-exponential-recency-weighted-completed-monthly-log-returns-three-month-half-life
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_QUEUED
last_updated: 2026-08-11
---

# QM5_20279 WTI Exponential-Recency Return Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20279_wti-expw-mom_card.md`.

## Hypothesis

A fixed base-two decay over twelve disjoint completed monthly WTI returns may
respond to a slow oil regime while retaining a full year of history. The
weight of information halves every three months. This is a direct crude-oil
structural carrier, not a profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes and form twelve chronological adjacent
log returns. Give the newest return age zero, weight each return by
`2^(-age/3.0)`, normalize by the twelve-weight total, buy when positive, sell
when negative, and consume exact-zero or invalid states flat. Renew at the
next month boundary. The canonical card locks chronology, age, base,
half-life, persisted attempt, ATR stop, spread cap, and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is APPROVED. Q01 is pending and Q02 is not queued.
