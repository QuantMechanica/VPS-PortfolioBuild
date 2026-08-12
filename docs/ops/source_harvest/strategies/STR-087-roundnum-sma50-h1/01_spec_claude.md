# STR-087 — Claude independent spec (pre-reconciliation)

Source: thread 922813 (Fx-ken, ~2019). Exec TF H1. Cohort: EURUSD.DWX,
GBPUSD.DWX (author showed EURUSD examples; test-design, flagged).

## Rules

1. SMA(50) close H1; horizontal grid every 25 pips at quarter levels
   (price endings .00000/.00250/.00500/.00750).
2. LONG side: price above SMA50 → pending BUY STOP at the nearest grid
   line ABOVE current price (line must itself be above the SMA) + 3-pip
   entry offset. SHORT mirror: nearest line below, − 3 pips.
3. TP 50 pips, SL 30 pips from entry (author's primary; the sideways
   25/25 variant = documented variant, unbuilt).
4. Proximity veto: skip when the candidate line is "too close" to the
   SMA50 — unquantified in source → input default 10 pips, PROVISIONAL
   (flagged; prior QM5_10039 used a similar gate).
5. BE move: once +10 pips in profit (the "10-15 pip" band, restrictive
   end), SL → BE+1 pip (BE+5 = variant). Once-latch.
6. Pending lifecycle: evaluated per closed H1 bar; re-point the single
   pending when the nearest valid line changes; cancel when the SMA side
   flips. One position; no immediate re-entry on the same line after SL
   (author: "I prefer 1 trade each") — mechanize: after SL, that line is
   blocked until price crosses the SMA or a different line qualifies
   (flagged minimal reading).

Prior QM5_10039 deltas (codex T6 contest): 3-bar pending expiry, 10-bar
position time exit, spread veto, opposite-grid distance gate — all
unsourced there, absent here.

## Inputs

```
strategy_sma_period = 50
strategy_grid_pips = 25.0
strategy_entry_offset_pips = 3.0
strategy_tp_pips = 50.0
strategy_sl_pips = 30.0
strategy_ma_proximity_pips = 10.0   // PROVISIONAL
strategy_be_trigger_pips = 10.0
strategy_be_plus_pips = 1.0
```

## Hooks sketch

Filter: H1/params/warmup ≥ 60. Entry: side + nearest-line + veto +
pending placement (state machine). Manage: pending re-point/cancel +
BE-latch. Exit: false. News: default.
