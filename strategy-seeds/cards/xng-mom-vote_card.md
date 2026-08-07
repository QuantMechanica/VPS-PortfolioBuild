---
copy_of: strategy-seeds/cards/approved/QM5_20259_xng-mom-vote_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XNG_MAJ1312_S13
variant_id: MOP-TSMOM-2012_XNG_MAJ1312_S13
source_id: MOP-XNG-MOMVOTE-2026
ea_id: QM5_20259
slug: xng-mom-vote
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-xng-one-three-twelve-month-return-sign-majority-vote
target_symbols: [XNGUSD.DWX]
period: D1
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
last_updated: 2026-08-07
---

# QM5_20259 XNG Multi-Horizon Momentum Vote

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20259_xng-mom-vote_card.md`.

## Hypothesis

Take monthly natural-gas exposure in the direction supported by at least two of its
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

G0 is approved under
`decisions/2026-08-07_qm5_20259_xng_mom_vote_g0.md`. Q01 has not run and Q02
is not enqueued; no baseline verdict is claimed.
