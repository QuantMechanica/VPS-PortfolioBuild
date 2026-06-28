---
ea_id: QM5_12746
slug: eia-wti-drive-pb
source_id: EIA-WTI-DRIVE-PB-2026
g0_status: APPROVED
---

# EIA WTI Driving-Season Pullback

Build-time copy of `strategy-seeds/cards/eia-wti-drive-pb_card.md`.

Framework alignment:
- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: driving-season D1 long pullback above slow SMA trend filter.
- trade_management: season-window end, trend failure, rebound SMA, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.
