# STR-058 — Claude independent spec (pre-reconciliation)

Source: thread 38981 (TheThing, 2006-07). Exec TF D1. Cohort: GBPUSD.DWX,
EURUSD.DWX (author: any pair, GBPUSD TP example → test-design, flagged).

## Version question (THE reconciliation point)

The OP's p.1 statement includes 20/50-EMA gates plus slope; the in-thread
requotes (p.7/13) of the "original" say "Daily Charts with NO Indicators"
(the OP apparently edited his post; the quotes preserve the pre-edit
text). BASELINE = p.1 (the OP's own final ruleset, EMA-gated); the bare
no-indicator form = documented variant.

## Rules (LONG; mirror short)

1. Three consecutive D1 candles with close > open (strict; a doji breaks
   the sequence).
2. EMA20(1) > EMA50(1) AND both slopes positive (minimal mechanization:
   ema(1) > ema(2) per line).
3. Entry at the open of the 4th candle (new-D1 evaluation, market order).
4. SL: 2 pips beyond the previous candle extreme OR 90 pips from entry —
   whichever gives the SMALLER distance ("whichever is lower").
5. MM (netted, 20101 machinery): close half at +30 pips and move SL to
   breakeven; TP remainder at +100 pips. The author's per-pair TP
   optimization remark is Q03 domain, not a build input.
6. One campaign; one evaluation per day; no re-entry same day.

Prior-build deltas (QM5_9966, codex deep-check): omitted the 30-pip half
close, added ATR/spread/opposite-signal gates and a different stop/exit
campaign — all absent here.

## Inputs

```
strategy_ema_fast       = 20
strategy_ema_slow       = 50
strategy_sl_buffer_pips = 2.0
strategy_sl_max_pips    = 90.0
strategy_p1_tp_pips     = 30.0
strategy_p2_tp_pips     = 100.0
```

## Hooks sketch

Filter: D1/params/warmup >= 55/handles (2 x iMA EMA). Entry: 3-candle +
EMA gates (own new-D1 guard). Manage: half-close at +30 touch + BE
(per-bar retry latch); TP2 server-side. Exit: false. News: default.

## Notes

Frequency est. 15-40/yr/symbol (D1 3-candle runs are common); floor safe.
