# Brent January Calendar Fade

Approved card: `artifacts/cards_approved/QM5_12871_brent-jan-fade.md`.

This EA mechanizes the approved Brent January calendar-fade card. It trades
only `XBRUSD.DWX` at D1, enters short on broker-calendar January bars, and exits
on the next D1 bar, month boundary, max-hold guard, or ATR hard stop.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and magic slot 0
(`128710000`). No live manifest, `T_Live` file, portfolio gate, or AutoTrading
control is touched by this build.
