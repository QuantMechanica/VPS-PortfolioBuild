---
ea_id: QM5_12740
slug: eia-wti-postdrive
source_id: EIA-WTI-POSTDRIVE-2026
g0_status: APPROVED
---

# EIA WTI Post-Driving-Season Breakdown

Build-time copy of `strategy-seeds/cards/eia-wti-postdrive_card.md`.

Framework alignment:
- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: post-driving-season D1 short breakdown.
- trade_management: season-window end, channel reversal, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.
