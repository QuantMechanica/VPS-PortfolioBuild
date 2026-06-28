---
ea_id: QM5_12737
slug: eia-wti-drive
source_id: EIA-WTI-DRIVE-2026
g0_status: APPROVED
---

# EIA WTI Driving-Season Breakout

Build-time copy of `strategy-seeds/cards/eia-wti-drive_card.md`.

Framework alignment:
- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: driving-season D1 long breakout.
- trade_management: season-window end, channel failure, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.
