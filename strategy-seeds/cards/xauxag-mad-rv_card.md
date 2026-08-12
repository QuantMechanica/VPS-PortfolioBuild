---
copy_of: strategy-seeds/cards/approved/QM5_20263_xauxag-mad-rv_card.md
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MADRV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MADRV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MAD-2026
ea_id: QM5_20263
slug: xauxag-mad-rv
status: APPROVED
g0_status: APPROVED
source_author: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-median-mad-robust-score-fresh-cross-reversion-basket
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
last_updated: 2026-08-07
---

# QM5_20263 XAU/XAG Robust Ratio Reversion

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20263_xauxag-mad-rv_card.md`.

## Hypothesis

Extreme synchronized gold/silver log-ratio displacements may converge. A
rolling median and median absolute deviation prevent one large observation
from redefining both the center and scale used to detect the excursion.

## Rules

Use separate 63-completed-D1 windows for the current and prior robust scores.
Enter one opposite-leg package only on a fresh `+/-2.0` crossing; exit inside
`+/-0.5`, on invalid package/state, or after 45 days. The canonical card locks
the exact formula, alignment, sides, shared fixed-risk budget, ATR stops,
spread caps, and no-retry excursion contract.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for one logical basket. No live artifact, portfolio
mutation, neutrality claim, or correlation waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Q01 passed strict
build validation. Q02 was not enqueued because the binding capacity sample
found nine governed factory terminals executing against the ceiling of seven.
Evidence: `docs/ops/evidence/2026-08-07_qm5_20263_xauxag_mad_rv_q01_cpu_stop.md`.
