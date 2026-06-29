# Natural Gas 12-Month TSMOM ATR Gate

Authoritative card:
`strategy-seeds/cards/approved/QM5_12804_xng-tsmom12m-atr_card.md`

This EA implements the approved `QM5_12804` structural natural-gas card:
monthly 12-month time-series momentum on `XNGUSD.DWX`, gated by fixed ATR%,
with ATR hard stop, monthly rebalance exit, and max-hold stale-position guard.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single
`XNGUSD.DWX` D1 setfile. No live manifest, AutoTrading, or portfolio gate files
are part of this build.
