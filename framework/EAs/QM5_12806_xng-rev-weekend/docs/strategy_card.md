# Natural Gas Reverse Weekend Effect

Authoritative card:
`strategy-seeds/cards/approved/QM5_12806_xng-rev-weekend_card.md`

This EA implements the approved `QM5_12806` structural natural-gas card:
buy `XNGUSD.DWX` on broker-calendar Monday, sell `XNGUSD.DWX` on
broker-calendar Friday, and flatten on the next D1 bar or the stale-position
guard. It uses MT5 OHLC and broker calendar state only.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single
`XNGUSD.DWX` D1 setfile. No live manifest, AutoTrading, or portfolio gate files
are part of this build.
