# STR-137 — Claude independent spec (pre-reconciliation)

Source: babypips thread 70731 (PhilipPirrip, 2015). Exec TF H4 (the
author's stated preference; D1 "keeps you in trades for years").
Cohort: EURUSD.DWX, USDJPY.DWX (his worked examples; test-design,
flagged).

## Rules (closed-bar)

1. EMA(20, close), EMA(50, close), Stochastic(14, 3, 1) applied to
   close (author: "regular settings applied to the close", K=14, D=3,
   slowing=1 — FLAGGED reading of his "set the D to 3 and K to 1"
   MT4 remark; price field CLOSE/CLOSE).
2. ARMED-LONG: EMA20 crosses above EMA50 (closed bar). Record the
   impulse anchors: swing low → swing high of the move that produced
   the cross — mechanize: low = lowest Low over the last
   strategy_anchor_lookback (50) bars before the cross; high = highest
   High from that low up to the cross bar, updated while armed until
   entry (FLAGGED — the author draws these by hand).
3. Entry LONG: while armed, wait for stochastic to reach OVERSOLD
   (K ≤ 20), then enter at the next bar open when K crosses back above
   20 (the "hook"; FLAGGED: cross-above-20 reading vs K-over-D).
   Armed state cancels on an opposite EMA cross. SHORT mirror
   (cross-down → wait overbought ≥ 80 → hook down).
4. Initial SL (HOUSE-HARD, labeled deviation): 10 pips beyond the
   impulse anchor extreme (his stated placement, which he himself
   treats as mental-only and overrides — his no-stop/-350-pip doctrine
   is inadmissible; our server-side stop is mandatory).
5. Fib-extension trail ladder from the anchors (low→high for longs):
   levels L = {1, 1.272, 1.618, 2, 2.618, 3, 3.618, 4, 4.618, 5}.
   When a bar CLOSES beyond level n: stop becomes "close beyond level
   n−1" — mechanize as close-based exit checks per bar (position
   closes at next bar if a close below level n−1 occurs); at first
   close above level 1 → hard SL to BE additionally (belt).
6. Opposite-signal exit: a completed opposite pattern (opposite cross
   + opposite hook) closes the position (his failure handling).
7. One position per magic; re-arm after flat on a fresh cross.

## Inputs

```
strategy_ema_fast = 20
strategy_ema_slow = 50
strategy_stoch_k = 14
strategy_stoch_d = 3
strategy_stoch_slowing = 1
strategy_os_level = 20.0
strategy_ob_level = 80.0
strategy_sl_buffer_pips = 10.0
strategy_anchor_lookback = 50
```

## Hooks sketch

Filter: H4/params/warmup ≥ 120. Entry: armed-state machine + hook
trigger. Manage: fib-ladder close-based trailing (per-bar, retry
latch), opposite-signal close. Exit: false. News: default.

Risk note: the author's zone levels (20/80 vs his screenshots) and
anchor definition are the two big interpretation surfaces —
reconciliation must converge them.
