---
ea_id: QM5_12738
slug: xng-weekend-gap
source_id: EIA-XNG-WEEKEND-GAP-2026
g0_status: APPROVED
---

# XNG Weekend Weather-Gap Continuation

Build-time copy of `strategy-seeds/cards/xng-weekend-gap_card.md`.

Framework alignment:
- no_trade: D1 and `XNGUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: confirmed Monday D1 weekend-gap continuation.
- trade_management: max-hold and signal-close invalidation exits.
- trade_close: hard ATR stop plus deterministic time/invalidation exits.
