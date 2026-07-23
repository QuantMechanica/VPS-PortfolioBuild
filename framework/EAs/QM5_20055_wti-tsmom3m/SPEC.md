# QM5_20055_wti-tsmom3m

Source-backed monthly WTI three-month time-series momentum. On the first D1
bar of each broker month, renew one `XTIUSD.DWX` package in the sign of the
completed 63-D1-bar log return. Use a frozen ATR(20) x 3.5 hard stop and a
31-day stale guard.

The approved card is
`strategy-seeds/cards/approved/QM5_20055_wti-tsmom3m_card.md`. This build is
RISK_FIXED backtest-only and has no live or portfolio authorization.
