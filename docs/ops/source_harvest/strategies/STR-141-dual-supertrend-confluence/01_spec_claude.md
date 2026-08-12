# STR-141 — Claude independent spec (pre-reconciliation)

Source: babypips thread 1152145 (sylc, 2023). Exec TF H1 (ledger; the
source names none — FLAGGED). Cohort: EURUSD.DWX, GBPUSD.DWX
(test-design; source names no symbol).

## Rules (closed-bar)

1. Indicators (all in-EA deterministic implementations):
   - Supertrend(7, 0.9) and Supertrend(7, 1.8): classic ATR(7)
     supertrend recursion on (high+low)/2, closed bars (no iCustom —
     inline math, FLAGGED implementation).
   - EMA(99, close); slope = sign(EMA[1] − EMA[2]) (ledger notes the
     posted code fragment says 9 — the prose says 99; prose wins,
     FLAGGED; 9 = variant).
   - RSI(9, close). ADX(9): trend gate ADX[1] > 25.
2. BUY: ST(7,0.9) flips bearish→bullish on the closed bar AND
   ST(7,1.8) already bullish AND EMA99 slope up AND RSI9[1] > 50 AND
   ADX9[1] > 25.
3. SELL (source-faithful ASYMMETRY, flagged): ST(7,1.8) flips
   bullish→bearish AND ST(7,0.9) already bearish AND EMA99 slope down
   AND RSI9[1] < 50 AND ADX9[1] > 25.
4. Exit long: EITHER supertrend flips bearish OR EMA99 slope turns
   down (closed bar; market close next bar, retry latch). Exit short
   mirror.
5. Initial SL (server-side): the ST(7,0.9) line value at entry for
   longs; the ST(7,1.8) line value for shorts (source-faithful
   asymmetry, flagged). Invalid geometry → skip.
6. No TP (exit-signal driven). One position per magic; re-entry on a
   fresh flip signal only.

## Inputs

```
strategy_st_atr_period = 7
strategy_st_fast_mult = 0.9
strategy_st_slow_mult = 1.8
strategy_ema_period = 99
strategy_rsi_period = 9
strategy_adx_period = 9
strategy_adx_min = 25.0
```

## Hooks sketch

Filter: H1/params/warmup ≥ 220. Entry: flip+confluence check (own
supertrend state arrays, closed-bar recursion). Manage: exit-signal
close + retry latch. Exit: false. News: default.

R1 caveat to record: author admits untested; replier: "not a system
until there's evidence" — pure falsification candidate.
