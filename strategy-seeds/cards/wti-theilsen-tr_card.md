---
copy_of: strategy-seeds/cards/approved/QM5_20271_wti-theilsen-tr_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_THEILSEN12_S20
variant_id: MOP-TSMOM-2012_XTI_THEILSEN12_S20
source_id: MOP-WTI-THEILSEN-2026
ea_id: QM5_20271
slug: wti-theilsen-tr
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-median-all-pairwise-log-price-slopes-over-thirteen-completed-month-ends
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
last_updated: 2026-08-10
---

# QM5_20271 WTI Theil-Sen Robust Trend

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20271_wti-theilsen-tr_card.md`.

## Hypothesis

The median of all forward pairwise slopes across thirteen completed monthly
WTI log prices may capture a persistent slow oil direction while resisting an
extreme endpoint that can rotate an OLS line. This is a direct crude-oil
structural carrier, not a profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes, form all 78 forward log-price slopes
using exact monthly-index distances, sort them, and average ascending indexes
38 and 39. Buy for a positive median slope, sell for a negative median slope,
and consume an exact-zero or invalid month flat. Renew at the next month
boundary. The canonical card locks endpoints, pair enumeration, denominator,
median indexes, sides, persisted attempt, ATR stop, spread cap, and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Deterministic
allocation and build/Q01 are PASS; Q02 work item
`62f9a076-8d5a-4da4-a246-bd0def468b05` is enqueued and pending.
