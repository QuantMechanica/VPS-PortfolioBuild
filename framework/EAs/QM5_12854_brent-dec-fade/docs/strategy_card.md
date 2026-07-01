# QM5_12854 Brent December Calendar Fade

Canonical card: `strategy-seeds/cards/approved/QM5_12854_brent-dec-fade_card.md`.

This EA mechanizes the Brent side of the Khan, Saha, and Ekundayo WTI/Brent
month-of-year weakness observation. It sells `XBRUSD.DWX` only on D1
broker-calendar December bars, uses an ATR hard stop, and exits on the next D1
bar, month exit, stale-position guard, or framework Friday close.

Backtest setfiles are fixed-risk only: `RISK_FIXED=1000` and `RISK_PERCENT=0`.
No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
