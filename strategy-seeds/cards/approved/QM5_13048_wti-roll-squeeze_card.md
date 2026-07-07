---
copy_of: strategy-seeds/cards/wti-roll-squeeze_card.md
copied_at: 2026-07-08
---

# QM5_13048 WTI ETF Roll-Window Squeeze Breakout

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/wti-roll-squeeze_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses the official CFTC crude-oil ETF
roll research paper as structural lineage but reads no ETF holdings, futures
curve, CFTC file, COT data, CSV, API, analyst calendar, or ML output at
runtime. It trades at most one early-month roll-window compression breakout per
broker-calendar month and exits by ATR stop/target, SMA failure, exit-window,
month change, time, standard news handling, and Friday close.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.
