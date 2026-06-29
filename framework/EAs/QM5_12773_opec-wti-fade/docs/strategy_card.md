---
ea_id: QM5_12773
slug: opec-wti-fade
type: strategy
source_id: OPEC-WTI-POSTFADE-2026
g0_status: APPROVED
---

# OPEC WTI Post-Window Impulse Fade

Build-time reference copy. Canonical card:
`strategy-seeds/cards/approved/QM5_12773_opec-wti-fade_card.md`.

Framework alignment:

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: June/December post-OPEC-window fade after event-window impulse
  proof and ATR/SMA stretch.
- trade_management: fade-window end, SMA mean reversion, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.
