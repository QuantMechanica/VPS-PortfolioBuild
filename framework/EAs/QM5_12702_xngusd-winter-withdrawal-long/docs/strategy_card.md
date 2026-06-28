---
ea_id: QM5_12702
slug: xngusd-winter-withdrawal-long
type: strategy
source_id: 706222b7-2d60-5fdb-8dab-d722d3c96f92
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
g0_status: APPROVED
---

# XNG Winter Withdrawal Long

Build-time card copy. Canonical research card:
`strategy-seeds/cards/xngusd-winter-withdrawal-long_card.md`.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, magic-slot guard, parameter guard, spread cap.
- trade_entry: monthly winter-withdrawal long entry after D1 SMA confirmation.
- trade_management: season end, SMA failure, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/season/trend exits.
