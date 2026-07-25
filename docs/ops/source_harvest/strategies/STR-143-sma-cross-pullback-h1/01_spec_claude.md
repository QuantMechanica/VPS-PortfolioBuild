# STR-143 — Claude independent spec (pre-reconciliation)

Source: babypips Art-of-Automation blog (2015-06-05; Big Pippin's SMA
Crossover Pullback mechanized by the blog author). Exec TF H1 (the
blog's EURUSD 1-hour chart). Cohort: EURUSD.DWX (blog example;
+GBPUSD.DWX test-design, flagged).

## Rules (closed-bar)

1. SMA(100, close), SMA(200, close), Stochastic(14, 3, 3).
2. Regime arming: upward SMA crossover = SMA100 crosses above SMA200
   (closed bar) → armed-long; downward → armed-short. Armed state
   persists until the opposite crossover.
3. BUY: the FIRST instance after arming that the stochastic "pulls up
   from the oversold area (25.00)" — mechanize: K[2] < 25 AND K[1] ≥
   25 (cross up through 25), first occurrence per armed episode only
   (FLAGGED: "first instance" = one trade per crossover episode...
   after the position closes, later hooks in the same episode do NOT
   re-enter). SELL mirror: first K cross down through 75.
4. Entry market at next bar open.
5. SL 150 pips; TP 300 pips (2:1). BE move: when price is +150 pips
   (= +1R), move SL to entry (once-latch).
6. One position per magic.
7. FLAGGED: the 150/300 pip constants are the blog's fixed values
   (2015 EURUSD volatility regime) — kept 1:1 per source-fidelity
   rule; Q02/Q03 judge.

## Inputs

```
strategy_sma_fast = 100
strategy_sma_slow = 200
strategy_stoch_k = 14
strategy_stoch_d = 3
strategy_stoch_slowing = 3
strategy_os_level = 25.0
strategy_ob_level = 75.0
strategy_sl_pips = 150.0
strategy_tp_pips = 300.0
strategy_be_trigger_pips = 150.0
```

## Hooks sketch

Filter: H1/params/warmup ≥ 220. Entry: armed-episode state + first
stoch-level cross. Manage: BE once-latch with retry pacing. Exit:
false. News: default.

Overlap: QM5_20143 (T12) is an EMA6/17-campaign M5 scalper — different
family. QM5_20138 (T11) stoch-zone H4 — different MA set/trigger. No
duplicate expected; reconciliation confirms.
