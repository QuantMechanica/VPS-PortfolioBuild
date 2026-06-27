---
ea_id: QM5_12609
slug: wti-cad-spread-mr
type: strategy
source_id: BOC-CAD-OIL-SPREAD-2026
g0_status: APPROVED
---

# WTI CAD Spread Mean Reversion

Build-time reference copy. Canonical card:
`strategy-seeds/cards/wti-cad-spread-mr_card.md`.

Framework alignment:

- no_trade: host chart guard, D1 guard, parameter guard, and spread caps.
- trade_entry: two-leg XTI/USDCAD log-spread z-score reversion basket.
- trade_management: package integrity repair only.
- trade_close: z-score reversion exit, max-hold exit, Friday close, and per-leg
  ATR stops.
