# QM5_20059_wti-tsmom6m

Source-backed monthly WTI six-month time-series momentum. On the first D1
bar of each broker month, renew one `XTIUSD.DWX` package in the sign of the
completed 126-D1-bar log return. Use a frozen ATR(20) x 3.5 hard stop and a
31-day stale guard.

The approved card is
`strategy-seeds/cards/approved/QM5_20059_wti-tsmom6m_card.md`. This build is
RISK_FIXED backtest-only and has no live or portfolio authorization.
