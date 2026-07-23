# QM5_20059 WTI Six-Month Momentum Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20059_wti-tsmom6m`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Source: Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
  Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`.

## Decision

Build one structural, low-frequency WTI sleeve using the sign of the
completed 126-D1-bar log return at each broker-month boundary. The package
renews monthly, uses a frozen ATR hard stop, and has a 31-day stale guard.

Exact dedup found no standalone six-month WTI sign implementation.
`QM5_20055` uses 63 D1 bars, `QM5_12616` uses a nine-month signal with a
three-month confirmation, `QM5_12603` uses 12 months, and `QM5_13150` counts
twelve monthly return signs. This medium-horizon XTI return driver is neither
the incumbent `QM5_12567` XNG RSI logic nor index/metal mean reversion.
Portfolio correlation remains a later evidence gate and is not pre-claimed.

## Validation And Enqueue

- Strategy Card schema lint: PASS; no missing sections or ML hits.
- Deterministic allocation: EA ID 20059; magic slot 0 = 200590000.
- Generated magic resolver contains 200590000.
- Strict compile and build check: PASS, 0 errors, 0 warnings.
- Binary SHA256:
  `68c79469f208abfd81dc1ddade107e4e771a1c512f526c964ad042563cc249be`.
- Backtest set SHA256:
  `fd9ae63814760a6e69c451c1c62a98bbc2345a832b258a59e57e2adc84e16c51`.
- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Q02 work item: `daa1463a-05ea-48bf-8f17-e4411c2da094`, pending,
  attempt 0.

The paced sweep enqueued exactly this EA/symbol. No manual backtest was
started. No T_Live, AutoTrading, live setfile, deploy manifest, portfolio
gate, portfolio manifest, or T_Live manifest was touched.
