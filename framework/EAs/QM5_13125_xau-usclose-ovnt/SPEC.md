# QM5_13125 XAU US-Close Overnight Drift

Mechanical implementation of the APPROVED `xau-usclose-ovnt` card. It buys
XAUUSD.DWX at broker 23:00 Monday through Thursday, applies a one-D1-ATR stop,
and exits at broker 16:00 on the following broker date.

All parameters are locked. No take profit, optimization branch, adaptive
filter, scale-in, grid, martingale, trailing stop, partial close, external
runtime feed, or ML is present.

Canonical card: `strategy-seeds/cards/xau-usclose-ovnt_card.md`.
