# QM5_20027 wti-dom26-short

**EA ID:** QM5_20027  
**Source:** BOROWSKI-WTI-DOM26-2016

Short `XTIUSD.DWX` on the opening of an actual D1 bar dated 26 and close at the
next D1 boundary. Never shift a missing date or retry a consumed monthly
attempt. Locked inputs: day 26, ATR(20) x 2.75 hard stop, one-day stale guard,
2500-point spread cap. Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.

Borowski (2016), section 4.3 and conclusion, reports the negative day-26 WTI
anomaly with `p=0.0424`. This build is research/backtest-only and grants no live
or portfolio authority.
