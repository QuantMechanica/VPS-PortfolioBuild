# STR-035 — Claude independent spec (pre-reconciliation)

Source: thread 230640 "A Simple London Breakout" (mer071898, 2010). Exec TF
M15. Symbols (author-monitored): EURUSD, GBPUSD, USDJPY, EURJPY, USDCHF
(.DWX).

## Core rules

1. **Box:** high/low of 03:00–06:00 **GMT** (author explicitly GMT-anchored
   with per-broker conversion instruction → mechanize via QM_BrokerToUTC;
   unlike the Knodlz server-anchored case, GMT-fixed is source-explicit).
   M15 bars whose open ∈ [03:00, 06:00) UTC.
2. **Box filter:** no trades if box size > 50 pips (author: "not ... over
   40-50 pips" → cap 50; input).
3. **Entries:** BUY STOP above box top, SELL STOP below box bottom, offset =
   `strategy_entry_ext_pct` × box size beyond the edge; default 32.6% (the
   midpoint of the author's "just between the 27 and 38.2 fib extensions";
   flagged mechanization of "just between").
4. **TP:** entry ± box size (in price; "Profit Target ... same amount of
   pips as the box size").
5. **SL:** the opposite side of the box (buy SL = box bottom; sell SL = box
   top — author's explicit clarification).
6. **One trade at a time** (author: "you are only in one trade on a pair at
   a time"): when one pending fills, delete the other. **Option B baseline**
   (author's preference): after the position closes (TP/SL) and before the
   next box, RE-PLACE both pendings at the same levels ("take all of the
   trades that present themselves").
7. **Reset:** at the next box start (03:00 UTC), close any open position
   and delete pendings (author's stated preference: "close all open trades
   before the start of the new box").

## Inputs

```
strategy_box_start_utc_hour = 3
strategy_box_end_utc_hour   = 6
strategy_entry_ext_pct      = 32.6   // "just between 27 and 38.2" (flagged)
strategy_max_box_pips       = 50.0
```

## Hooks sketch

- NoTradeFilter: M15; params; warmup ≥ 1 day.
- EntrySignal: box build at box end (UTC via framework primitive); validity
  (size ≤ cap, levels legal); two-phase placement state machine (one
  request per call, 20107 pattern); re-arm state (flat + before next box →
  re-place).
- Manage: on fill → delete opposite pending (one-at-a-time); at box start →
  flatten + delete (STRATEGY_EXIT reason=box_reset).
- ExitSignal: false. NewsFilterHook: default.

## Notes

- Overlap QM5_20045 (ledger): a different London-box build from an earlier
  wave — differentiate via its SPEC (fib-extension entries + box-size TP/SL
  + option-B re-arm are this thread's signature).
- Martingale musings in-source are NOT built (hard rule).
- Frequency ~200+/yr. Later-thread indicator versions (V7-V9, trailing,
  break-even) = variants, unbuilt.
