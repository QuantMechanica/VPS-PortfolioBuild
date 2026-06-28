---
copy_of: strategy-seeds/cards/approved/QM5_12750_wti-weekend-gap-fade_card.md
---

# Strategy Card Copy

This EA mechanizes `QM5_12750_wti-weekend-gap-fade` for `XTIUSD.DWX` on D1.

Framework alignment:
- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: Monday positive weekend-gap short against prior Friday close.
- trade_management: non-Monday stale exit and max-hold guard.
- trade_close: hard ATR stop plus broker-side gap-fill TP.
