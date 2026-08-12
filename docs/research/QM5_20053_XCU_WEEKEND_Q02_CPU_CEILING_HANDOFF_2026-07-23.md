# QM5_20053 XCU Weekend Q02 CPU-Ceiling Handoff

QM5_20053 is a new structural copper weekend-premium sleeve sourced from the
OWNER-approved Borowski-Lukasik metals-seasonality packet. It is non-duplicate
calendar logic: buy XCUUSD.DWX at broker Friday 21:00 and close at the first
Monday H1 boundary, with a fixed-risk ATR stop.

Card lint, deterministic build preflight, strict compile, and EA-specific build
check pass. The binary compiled with zero errors and zero warnings. The
backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.

No Q02 work item was inserted. At the 2026-07-23 handoff, T1, T2, T3, T4, T6,
T7, T8, and T9 were occupied; five were running active Q02 work items and the
farm reported 30 pending P2 jobs. The fleet mission explicitly required a stop
at the backtest CPU ceiling, so no smoke/backtest was launched and no duplicate
queue row was fabricated.

When capacity is available, bind the existing build task
`10c28272-d6c3-4c80-9325-1d7758d8acd0`, run the single governed smoke, complete
review, and enqueue exactly one logical Q02 row for XCUUSD.DWX H1.

No T_Live, AutoTrading, deploy manifest, portfolio gate, or live manifest was
touched.
