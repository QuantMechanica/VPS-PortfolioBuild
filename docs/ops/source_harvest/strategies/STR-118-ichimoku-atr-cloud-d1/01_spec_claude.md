# STR-118 — Claude independent spec (pre-reconciliation)

Source: babypips thread 18242 (unhommefou's mechanized simplification,
2009, posts #25-36; NOT the OP's Chikou version). Exec TF D1 (author:
"Daily did better than Hourly, Weekly worked the best" — weekly is
MN1-adjacent/untestable-class, D1 = his published results). Cohort:
USDJPY.DWX (author's best performer) + EURUSD.DWX. AUD pairs BANNED by
the author ("EVERY AUD PAIR IS A MAJOR LOSER").

## Rules (closed-bar)

1. Ichimoku(9, 26, 65) — the author's walk-forward-tested best
   ("without a shadow of a doubt 9,26,65"); classic 9,26,52 = variant.
   ATR filter: "1 × the 20-period moving average of the ATR above the
   cloud" — FLAGGED reading: SMA(20) of ATR(1)?? Mechanize as
   ATR(20) on D1 (the natural "moving average of the true range over
   20 periods"); reconciliation decides.
2. LONG entry: Tenkan[1] > Kijun[1] AND Close[1] ≥ max(SenkouA[1],
   SenkouB[1]) + 1×ATR — price must clear BOTH cloud edges by the ATR
   distance (p.8: "above the Cloud (Senkanspan b AND a)").
3. LONG exit: Tenkan crosses below Kijun (closed bar). SHORT mirror
   (below min(SenkouA,SenkouB) − ATR; exit on cross up).
4. Chikou conditions = the OP's version, NOT this baseline (the
   backtest "did not take into account the Chousu Span" and the
   simplification drops it) — documented variant.
5. NO pyramiding: the author's 3-lot ATR scale-in is stacking —
   excluded per house rules; his 1-lot base results stand alone.
6. No source SL/TP — exit is the opposite cross. House catastrophic
   stop: 4×ATR(20) server-side SL at entry (QM5_20127 Sisyphus
   precedent), FLAGGED house addition, labeled.
7. Senkou values read at the CURRENT bar position (the cloud drawn
   under price, i.e. projected 26 bars earlier — standard iIchimoku
   buffer semantics at shift 1). FLAGGED implementation detail.
8. One position per magic; entry next bar after signal.

## Inputs

```
strategy_tenkan = 9
strategy_kijun = 26
strategy_senkou = 65
strategy_atr_period = 20
strategy_atr_cloud_mult = 1.0
strategy_catastrophic_atr = 4.0
```

## Hooks sketch

Filter: D1/params/warmup ≥ 130 D1 bars + iIchimoku/ATR handles. Entry:
alignment + ATR-distance check. Manage: opposite-cross close (market),
per-bar retry latch. Exit: false (cross handled in Manage for
determinism? — no: Exit hook returns true on opposite cross; simpler).
News: default.
