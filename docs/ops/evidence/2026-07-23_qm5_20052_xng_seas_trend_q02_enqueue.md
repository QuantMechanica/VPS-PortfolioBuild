# QM5_20052 XNG Seasonal-Window Trend Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20052_xng-seas-trend`
- Symbol/timeframe: `XNGUSD.DWX` D1
- Sources: Suenaga-Smith-Williams (2008) natural-gas volatility seasonality; Moskowitz-Ooi-Pedersen (2012) time-series momentum.

## Decision

Build one structural low-frequency XNG sleeve: at monthly rebalance, trade the sign of the closed 126-D1 return only during May-September and November-January. Exit at the next rebalance, after 31 days, or when the source season ends.

This is not `QM5_12567` cumulative-RSI2 reversion, not the `QM5_13110` weekly H4 prior-range breakout, and not unconditional energy momentum. The physical volatility-season gate is binding.

## Validation

- Strategy Card schema lint: PASS; no missing sections or ML hits.
- Deterministic allocation: EA ID 20052; magic slot 0 = 200520000.
- Strict compile and build check: PASS, 0 errors, 0 warnings.
- Final binary SHA256: `7b0b6b8e84724b41b4134341fc9f520e4e7f319339aa659cc36183a2e7143749`.
- Setfile build hash: `e67e6d220ae8d8adfdaf48e85df355c0b657c5109ac83622f366e39e546f9f54`.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1.
- Q02 work item: `1b23a273-e5bc-497d-b55d-aca566da98da`, pending, attempt 0.

## Paced Q02 Outcome

The fleet claimed the row after enqueue and completed it before closeout. Q02
returned `FAIL / MIN_TRADES_NOT_MET`: 24 trades versus the 25-trade floor,
profit factor 0.00, net profit -998.42, and 1.00% drawdown over 2018-07-02 to
2022-12-31. Evidence: `D:/QM/reports/work_items/1b23a273-e5bc-497d-b55d-aca566da98da/QM5_20052/20260723_003733/summary.json`.

This edge is built and falsified at Q02; it is not a certified portfolio
addition and is not promoted or reworked in this mission.

No backtest was manually started. No T_Live, AutoTrading, live setfile, deploy manifest, portfolio gate, or T_Live manifest was touched.
