---
ea_id: QM5_12733
slug: xti-xng-xmom
type: strategy
source_id: SRC05_S10_XTI_XNG_XMOM_2026
g0_status: APPROVED
---

# XTI/XNG Energy Cross-Sectional Momentum

Build-time reference copy. Canonical card:
`strategy-seeds/cards/approved/QM5_12733_xti-xng-xmom_card.md`.

Framework alignment:

- no_trade: host chart guard, D1 guard, parameter guard, spread caps.
- trade_entry: monthly XTI/XNG prior-return rank; long stronger energy leg, short weaker leg.
- trade_management: package integrity only.
- trade_close: monthly rebalance exit, max-hold exit, Friday close, per-leg ATR stops.
