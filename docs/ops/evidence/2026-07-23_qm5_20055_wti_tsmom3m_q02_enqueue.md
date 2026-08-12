# QM5_20055 WTI Three-Month Momentum Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20055_wti-tsmom3m`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Source: Moskowitz, Ooi and Pedersen (2012), *Journal of Financial
  Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

## Decision

Build one structural, low-frequency WTI sleeve using the sign of the completed
63-D1-bar return at each broker-month boundary. The package renews monthly,
uses a frozen ATR hard stop, and has a 31-day stale guard.

This is not the 12-month WTI trend in `QM5_12603`, the 9-month signal plus
3-month confirmation in `QM5_12616`, or the twelve monthly-sign breadth state
in `QM5_13150`. It introduces XTI exposure to the XAU/SP500/NDX/XNG book; later
pipeline correlation evidence, not this build, decides whether it is genuinely
orthogonal.

## Validation And Enqueue

- Strategy Card schema lint: PASS; no missing sections or ML hits.
- Deterministic allocation: EA ID 20055; magic slot 0 = 200550000.
- Generated magic resolver contains 200550000.
- Strict compile and build check: PASS, 0 errors, 0 warnings.
- Binary SHA256:
  `cb187e829febacae7a8bffa2896bf54ad1a86969092179a3252e729e80fc1d4a`.
- Backtest setfile: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Q02 work item: `425d98e6-2234-469b-9f49-ab5ae9da0d6f`, pending,
  attempt 0.

The paced sweep enqueued exactly this EA/symbol. No manual backtest was
started. No T_Live, AutoTrading, live setfile, deploy manifest, portfolio gate,
portfolio manifest, or T_Live manifest was touched.
