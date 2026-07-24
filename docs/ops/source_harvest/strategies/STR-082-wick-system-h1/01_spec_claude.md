# STR-082 — Claude independent spec (pre-reconciliation)

Source: thread 771822 (michaellobry, ~2018; "wick system 1.00"). Exec TF
H1. Cohort: EURUSD.DWX, GBPUSD.DWX (source names none; test-design,
flagged).

## Rules

1. On each new H1 bar, compare the previous candle's wicks:
   lower = min(open,close) − low; upper = high − max(open,close).
2. lower > upper → BUY; lower < upper → SELL; tie → nothing (strict).
3. Entry at the new bar ("at exactly close of previous candle" = next
   open). TP 50 pips / SL 50 pips.
4. HOUSE DEVIATION (mandatory): the source opens EVERY hour regardless of
   open positions (unbounded stacking — inadmissible). Baseline: ONE
   position; a new signal is taken only when flat (more restrictive;
   explicitly tagged). The hourly-stacked source mode is documented,
   unbuilt.
5. No other filters (the thread's swing/anti-trade parameter ideas =
   participant variants, unbuilt).

Prior QM5_10047 deltas (codex T6): 0.25×ATR range filter,
weekday/session, spread, 12-bar time filters added — all absent here.

## Inputs

```
strategy_tp_pips = 50.0
strategy_sl_pips = 50.0
```

## Hooks sketch

Filter: H1/params/warmup ≥ 3 bars. Entry: wick comparison (own guard;
flat-only). Manage: empty. Exit: false. News: default.

## Notes

Flat-only converts the source's continuous exposure into sequential
50/50 coin-flip-with-edge tests — the honest single-position
falsification of the wick hypothesis; churn moderate (positions live
multiple bars on 50-pip targets).
