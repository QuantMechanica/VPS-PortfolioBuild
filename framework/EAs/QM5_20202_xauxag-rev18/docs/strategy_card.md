---
copy_of: strategy-seeds/cards/approved/QM5_20202_xauxag-rev18_card.md
strategy_id: BIANCHI-MOMREV-2015_XAU_XAG_S03
source_id: BIANCHI-MOMREV-2015
ea_id: QM5_20202
slug: xauxag-rev18
status: APPROVED
g0_status: APPROVED
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_20202_XAU_XAG_REV18_D1
period: D1
---

# Build-Time Card Reference

Canonical rules:
`strategy-seeds/cards/approved/QM5_20202_xauxag-rev18_card.md`.

The build must retain synchronized completed 18-month returns, the pure
long-loser/short-winner rank rule, one consumed attempt per broker month, one
aggregate fixed-risk budget, frozen per-leg ATR stops, next-month/stale exits,
and two-leg lifecycle repair. It must not consult the 12-month rank used by
S02. No live or portfolio artifact is authorized.
