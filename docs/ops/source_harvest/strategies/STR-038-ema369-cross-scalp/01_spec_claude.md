# STR-038 — Claude independent spec (pre-reconciliation)

Source: thread 252779 "3,6,9 EMA system" (jaws810, ~2010). Exec TF M5.
Symbols: source says "any pair"; cohort = EURUSD.DWX, GBPUSD.DWX
(test-design, flagged).

## Core rules

1. EMA(3), EMA(6), EMA(9) on M5 close.
2. BUY when EMA3 crosses above BOTH EMA6 and EMA9 on the closed bar:
   ema3(1) > ema6(1) AND ema3(1) > ema9(1) AND NOT(ema3(2) > ema6(2) AND
   ema3(2) > ema9(2)) — full-condition edge (handles staggered crosses).
   SELL mirror. Entry at next bar open ("all trades made after the close of
   the candle where the cross occurred").
3. TP = 10 pips (author's "approximately 10 pips"; his 2.5%-of-balance
   alternative is broker-feature-specific and NOT mechanized — flagged).
4. SL = 20 pips (disaster stop, source-fixed).
5. **Opposite-cross exit:** when the opposite full cross condition becomes
   true on a closed bar and a position is open → close at market (author:
   losers are taken out by the opposite cross). Implemented in ExitSignal
   (level condition, closed-bar, restart-safe).
6. One position; a close-by-opposite-cross may be immediately followed by
   the mirrored entry on the same bar evaluation (stop-and-reverse
   effectively; mechanize: exit first, entry next bar — no same-tick
   reversal; flagged minimal reading).
7. No ranging filter (thread suggests separation filters — variants,
   unbuilt; source baseline has none).

## Inputs

```
strategy_ema_fast   = 3
strategy_ema_mid    = 6
strategy_ema_slow   = 9
strategy_tp_pips    = 10.0
strategy_sl_pips    = 20.0
```

## Hooks sketch

Filter: M5/params/warmup ≥ 9+5/handles. Entry: edge condition, own guard.
Manage: empty. ExitSignal: opposite full-cross level condition (bar-gated
internal read). News: default.

## Notes

- Overlap QM5_9970 (ledger) — earlier triple-EMA build; differentiate.
- Extreme churn expected (M5 3/6/9 crosses = several/day) — Q02 economics
  will judge brutally; falsification build (thread itself predicts ranging
  destruction).
