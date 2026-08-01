---
copy_of: strategy-seeds/cards/approved/QM5_20194_xauxag-momrev_card.md
strategy_id: BIANCHI-MOMREV-2015_XAU_XAG_S02
source_id: BIANCHI-MOMREV-2015
ea_id: QM5_20194
slug: xauxag-momrev
status: APPROVED
g0_status: APPROVED
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_20194_XAU_XAG_MOMREV_D1
period: D1
---

# Build-Time Card Reference

Canonical rules:
`strategy-seeds/cards/approved/QM5_20194_xauxag-momrev_card.md`.

The build must retain synchronized overlapping 12/18 completed-month returns,
the strict opposite-rank gate, one consumed attempt per broker month, one
aggregate fixed-risk budget, frozen per-leg ATR stops, next-month/stale exits,
and two-leg lifecycle repair. No live or portfolio artifact is authorized.
