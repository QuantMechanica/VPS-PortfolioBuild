# QM5_20021_wti-h2m-short - Strategy Spec

EA ID `20021`; source `BOROWSKI-WTI-H2M-2016`; target `XTIUSD.DWX` D1 slot 0.

Short the D1 bar dated exactly 16 and flatten at the first D1 bar of the next
broker month, with a 16-day stale guard and frozen `2.75 * ATR(20)` stop.
Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. Borowski (2016), Section
4.4/Table 2, reports crude oil's days 16-month-end mean as `-0.0824%` versus
`-0.0148%` in days 1-15, but no significant difference (`p=0.5271`).

No live setfile, deploy manifest, AutoTrading, T_Live action, portfolio
admission or gate change is authorized.
