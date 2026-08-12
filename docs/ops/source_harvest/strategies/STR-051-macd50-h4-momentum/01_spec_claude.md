# STR-051 — Claude independent spec (pre-reconciliation)

Source: thread 33362 (the_guvnor, 2007). GBPUSD.DWX H4 only
(author-explicit single pair).

## Rules

1. MACD(5,13,1) main line, H4 closed bars.
2. Decision at H4 bar closes whose broker-hour is one of 8/12/16/20 (the
   author checked four times daily 08-20 UK on his 4h grid; our NY-close
   broker grid has bars at 0/4/8/12/16/20 broker — the 00/04 closes are
   skipped, mirroring his UK-night skip). GRID-OFFSET AMBIGUITY FLAGGED:
   his UK bar boundaries sit ~2h from ours; exact reproduction of his grid
   is impossible on our chart — documented approximation.
3. delta = MACD_main(1) − MACD_main(3) (his "difference between the 3
   previous MACD signals"; both prior mechanizations agree on shift 1 vs
   shift 3). delta >= +0.00050 → LONG; <= −0.00050 → SHORT. Entry at the
   evaluation bar open (next tick).
4. Campaign (source: two positions P1 TP30/SL30, P2 TP45/SL30 with BE at
   +30): netted ONE position — close HALF at +30 pips and move SL to
   breakeven; TP remainder +45 pips; initial SL 30 pips. Campaign risk 1%
   total (20101 convention, more restrictive than 2 positions at full
   size).
5. One campaign at a time (source: "if there are no trades open").

Prior-build deltas (QM5_10043, codex contest): collapsed the two-lot
30/45 realization into one 45-pip target and added ATR-range and spread
vetoes — all absent here.

## Inputs

```
strategy_macd_fast    = 5
strategy_macd_slow    = 13
strategy_macd_signal  = 1
strategy_delta_price  = 0.00050
strategy_p1_tp_pips   = 30.0
strategy_p2_tp_pips   = 45.0
strategy_sl_pips      = 30.0
```

## Hooks sketch

Filter: H4/params/warmup/handle (iMACD main buffer). Entry: hour-gated
delta check (own new-bar guard). Manage: half-close at +30 touch + BE
(per-bar retry latch); TP2 server-side at entry. Exit: false. News:
default.

## Notes

Frequency est. 60-150 signals/yr; single-pair GBPUSD; author backtest
claims unaudited (2007 thread).
