---
canonical_card: strategy-seeds/cards/xng-tom-mom_card.md
---

# Strategy Card Copy - QM5_13009_xng-tom-mom

Build-time reference for `strategy-seeds/cards/xng-tom-mom_card.md`.

This EA trades only `XNGUSD.DWX` on D1. It enters at most once per
broker-calendar turn-of-month cycle in the direction of a fixed completed-D1
momentum lookback, then exits when the turn window ends, a stale-position guard
fires, or the ATR stop/target is hit.

The build is intentionally separate from `QM5_12567_cum-rsi2-commodity` because
it has no RSI, oscillator, short-horizon pullback, grid, martingale, or ML
logic. It also avoids T_Live, AutoTrading, deploy manifests, and portfolio gate
files.
