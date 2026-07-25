# STR-120 — Claude independent spec (pre-reconciliation)

Source: babypips thread 326993 (Cloudninee, 2020). Exec TF H1.
Cohort: the author's six pairs — EURGBP, EURUSD, GBPJPY, GBPUSD,
USDCHF, USDJPY (.DWX; source verbatim). EURGBP/GBPJPY availability to
verify at build.

## Rules (closed-bar)

1. Range: high/low of the LAST 3 H1 candles before London open —
   concretized by the thread's own example (#67: "5, 6 and 7 am") as
   the H1 bars opening 05:00, 06:00, 07:00 UK-local; London open =
   08:00 UK-local. UK-DST-aware in-EA (QM5_20119 pattern). FLAGGED
   concretization.
2. After London open: when an H1 candle CLOSES beyond the range high
   → market BUY at that close; beyond the low → SELL. First qualifying
   close wins the day.
3. SL at the OPPOSITE range end (entry-to-opposite-side distance,
   author-clarified #68). TP = 1.5× that distance.
4. Time exit: close the position just before US market close —
   mechanize 21:00 UK-local ≈ 16:00 NY-local (FLAGGED: author says
   "just before the US market closes"; pick 16:45 NY-local, input).
5. ONE trade per day; after SL NO re-entry ("I don't reenter even if
   it breaks through to the other side", #68). Day state resets at the
   next range build.
6. No other filters (no range-size veto — the author skipped huge
   ranges discretionarily (#64), unsourced as a rule → excluded,
   flagged as observed discretion).
7. Risk 1-2%/trade in source → house ≤1% RISK_PERCENT live,
   RISK_FIXED backtest.

## Inputs

```
strategy_range_hours = 3
strategy_london_open_uk_hour = 8
strategy_tp_r = 1.5
strategy_close_ny_hour = 16
strategy_close_ny_min = 45
```

## Hooks sketch

Filter: H1/params/warmup. Entry: false — day state machine in Manage
(close-confirmed market entries, one-per-day latch, time exit). Manage:
range build, breakout detect, time exit with per-bar retry. Exit:
false. News: default.

Overlap: QM5_20111 london-box-fib-straddle = pending-straddle with fib
targets (different mechanics); QM5_20107/9936 = USDJPY Asian straddles.
This is a close-confirmed London ORB with 3-candle range — distinct
entry paradigm (close-through vs stop-order), but same session-
structure family; document in reconciliation.
