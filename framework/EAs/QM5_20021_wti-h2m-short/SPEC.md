# QM5_20020_wti-dom17-short - Strategy Spec

EA ID `20020`; source `BOROWSKI-WTI-DOM17-2016`; target `XTIUSD.DWX` D1 slot 0.

At a new broker D1 bar dated exactly the 17th, consume the month's decision and
attempt one short with a frozen `2.75 * ATR(20)` stop. Never shift a missing
17th. Close at the next D1 bar, with a one-calendar-day stale guard and Friday
21:00 broker flattening. Locked spread cap is 2500 points. Backtests use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

Borowski (2016), Section 4.3, reports day 17 as crude oil's lowest mean session
(`-0.7016%`) in 1983-2016 NYMEX futures. It does not report day 17 significant;
the broad uncorrected calendar search, post-2016 decay and futures/CFD basis are
explicit kill risks. The approved card is
`strategy-seeds/cards/wti-dom17-short_card.md`.

No live setfile, deployment manifest, AutoTrading, T_Live action, portfolio
admission or portfolio-gate change is authorized.
