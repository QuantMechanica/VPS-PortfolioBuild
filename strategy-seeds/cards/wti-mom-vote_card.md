---
copy_of: strategy-seeds/cards/approved/QM5_20258_wti-mom-vote_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_MAJ1312_S12
variant_id: MOP-TSMOM-2012_XTI_MAJ1312_S12
source_id: MOP-WTI-MOMVOTE-2026
ea_id: QM5_20258
slug: wti-mom-vote
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-one-three-twelve-month-return-sign-majority-vote
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
last_updated: 2026-08-07
---

# QM5_20258 WTI Multi-Horizon Momentum Vote

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20258_wti-mom-vote_card.md`.

## Hypothesis

Take monthly WTI exposure in the direction supported by at least two of its
completed one-, three-, and twelve-month return signs.

## Rules

The canonical card locks thirteen consecutive month ends, the exact nested
one/three/twelve-month returns, strict nonzero component signs, a two-of-three
vote, one consumed attempt per month, monthly package renewal, and a frozen ATR
hard stop.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live artifact or portfolio mutation is authorized.

## Pipeline Status

Q01 passed the strict compile and target-scoped build gate on 2026-08-07.
Q02 is enqueued as pending work item
`ff028e35-d4c2-49ad-98c4-e0acc80b55c5`; no baseline verdict is claimed.
