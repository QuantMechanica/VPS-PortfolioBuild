# STR-085 — Claude independent spec (pre-reconciliation)

Source: thread 837301 (GazFx, ~2018; Seiden-derived). Exec TF H4
(author's TF). Cohort: EURUSD.DWX, GBPUSD.DWX (any-symbol source;
test-design, flagged).

## Rules

1. Stochastic(5,3,3, CLOSE/CLOSE price field) + EMA(50) close, H4.
2. BUY: stoch cross-up on the closed bar (K(1)>D(1), K(2)<=D(2)) with the
   cross in the ≤20 zone (mechanize: D(1) <= 20; flagged which-line
   choice) AND EMA50 sloping UP (ema(1) > ema(2), minimal; equality =
   flat = no trade — the author's discretionary flat filter mechanized
   minimally, flagged). SELL mirror (≥80 zone, slope down).
3. Entry next bar. SL just beyond the previous bar's extreme with a
   10-pip buffer (long: Low(2)... the "previous low" = the signal bar's
   prior low? Mechanize: min(Low(1), Low(2)) − 10 pips; flagged). TP =
   3 × SL distance.
4. Trailing stop = the entry-SL distance (MT4-style ratchet once
   profitable, never widen).
5. One position.

Prior QM5_10017 deltas (codex T6): 5-bar structure stop, ATR slope
quantification, max-stop/time/opposite-cross rules — absent here.

## Inputs

```
strategy_stoch_k = 5
strategy_stoch_d = 3
strategy_stoch_slow = 3
strategy_ema_period = 50
strategy_zone = 20.0
strategy_sl_buffer_pips = 10.0
strategy_tp_r = 3.0
```

## Hooks sketch

Filter: H4/params/warmup ≥ 60/handles (iStochastic STO_CLOSECLOSE, iMA).
Entry: cross+zone+slope. Manage: ratchet trail at SL-distance.
Exit: false. News: default.
