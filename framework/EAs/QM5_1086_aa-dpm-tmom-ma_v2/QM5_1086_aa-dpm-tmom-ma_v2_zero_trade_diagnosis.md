# QM5_1086 v2 Zero-Trade Diagnosis

## Smoke Results

1. `D:/QM/reports/smoke_task028/QM5_1086/20260517_183920/summary.json`
   - Symbol: `NDX.DWX`
   - Window: 2024
   - Period: D1
   - Result: FAIL, `MIN_TRADES_NOT_MET`
   - Trades: 0/0 across 2 deterministic runs

2. `D:/QM/reports/smoke_task028/QM5_1086/20260517_184021/summary.json`
   - Symbol: `NDX.DWX`
   - Window: 2020-2024
   - Period: D1
   - Result: FAIL, `MIN_TRADES_NOT_MET`
   - Trades: 0

## Diagnosis

v2 fixed the obvious implementation mismatch: v1 was an H1-only port of a monthly close allocation rule. The source rule still produced no entries after moving to D1 and using a 252-trading-day proxy for the 12-month lookback.

Likely remaining issue: the implementation tries to convert a 100%/50%/0% allocation model into single-position entry/exit events. In periods where the strategy should already be in a long allocation from before the test window, the EA starts flat and waits for a new rebalance transition; if the target exposure remains positive, no fresh transition is created.

## v3 Ideas

- Add a bootstrap entry mode: if target exposure is positive at the first eligible rebalance inside the test window, open the position even without a transition from cash.
- Simplify to binary source-compatible exposure for smoke: long when either TMOM or MA is positive, flat only when both are negative.
- Add diagnostic `PrintFormat` lines around monthly rebalance, target exposure, and ATR stop rejection to distinguish signal absence from trade-open rejection.

No P2 enqueue was created because smoke still had 0 trades.
