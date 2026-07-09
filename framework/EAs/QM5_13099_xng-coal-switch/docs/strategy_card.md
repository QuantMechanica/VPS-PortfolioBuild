---
copy_of: strategy-seeds/cards/approved/QM5_13099_xng-coal-switch_card.md
ea_id: QM5_13099
slug: xng-coal-switch
source_id: EIA-XNG-COAL-SWITCH-2026
status: APPROVED
---

# Strategy Card Copy - QM5_13099_xng-coal-switch

Build-time reference for
`strategy-seeds/cards/approved/QM5_13099_xng-coal-switch_card.md`.

The EA trades `XNGUSD.DWX` D1 long-only during spring and early-autumn
shoulder windows. It requires a bottom-quartile 252-D1 closing-price rank plus
a bullish SMA reclaim, ATR-sized range, and upper-bar close. It exits on ATR
stop/target, normalized price rank, SMA failure, max hold, or framework Friday
close. Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The source is the official EIA natural-gas price-driver and coal/gas dispatch
packet. The full card documents the explicit non-duplicate boundary against
RSI2, six-month reversal, summer-power, compression, seasonal, event, and
basket XNG sleeves.

