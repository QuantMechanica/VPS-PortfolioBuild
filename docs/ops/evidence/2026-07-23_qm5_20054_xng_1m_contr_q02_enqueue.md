# QM5_20054 XNG One-Month Contrarian Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20054_xng-1m-contr`
- Symbol/timeframe: `XNGUSD.DWX` D1
- Source: Mishra and Smyth (2016), *Economic Modelling* 54, 178-186,
  DOI `10.1016/j.econmod.2015.12.034`.

## Decision

Build one structural, low-frequency XNG sleeve from the paper's explicitly
tested one-month trading frequency. On every broker-month boundary, buy after
a negative completed-month return and sell after a positive return; equality
retains the prior state. The package renews monthly with a frozen ATR stop and
40-day stale guard.

This is not `QM5_12567` cumulative-RSI2 reversion: it has no RSI, two-day
accumulation, SMA alignment or five-bar exit. It also differs from
`QM5_20013_xng-2m-contr` in observation horizon, renewal cadence and state path.

## Validation And Enqueue

- Strategy Card schema lint: PASS; no missing sections or ML hits.
- Deterministic allocation: EA ID 20054; magic slot 0 = 200540000.
- Strict compile and build check: PASS, 0 errors, 0 warnings.
- Binary SHA256:
  `88e79e36538a05c5d30f976d3dc6b89d2dbd1a70f732fe0bc7fdb7cad44c1cfc`.
- Backtest setfile: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Q02 work item: `0f1bbf02-e1ea-49b4-9e41-04c72a1ff8e8`, pending,
  attempt 0.

The paced sweep enqueued exactly this EA/symbol. No manual backtest was
started. No T_Live, AutoTrading, live setfile, deploy manifest, portfolio gate
or T_Live manifest was touched.
