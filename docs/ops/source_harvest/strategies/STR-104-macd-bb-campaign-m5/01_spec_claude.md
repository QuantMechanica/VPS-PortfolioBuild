# STR-104 — Claude independent spec (pre-reconciliation)

Source: babypips thread 1266726 (Eliteforexpartner, 2024-12). Exec TF
M5 (thread title). Cohort: EURUSD.DWX (tight-spread major; author:
"any market", ECN/tight spread emphasized; single-symbol baseline,
flagged — M5 churn risk).

## Rules (campaign state machine, closed-bar)

1. Indicators: MACD(6,17,1) zero-line state — mathematically identical
   to EMA(6) vs EMA(17) cross (thread post #2 proof; implement via
   pooled EMA readers, flagged equivalence). BB(period 10, shift 1,
   deviation 0.66) on close.
2. BUY campaign starts when EMA6 crosses above EMA17 (zero-line
   cross-up) on a closed bar. Any cross below zero aborts the buy
   campaign and starts a sell campaign (and cancels pendings).
3. Phase PULLBACK: track campaign high = highest High since campaign
   start. Pullback confirmed when a bar's high/close re-enters the BB
   channel (close ≤ upper band; "doesn't matter if it closes below the
   bands"). FLAGGED reading: price touching/entering the band zone.
4. Phase BREAKOUT-WAIT: after the pullback, wait for a bar that CLOSES
   above the campaign high. Then place BUY STOP at high + 1 pip.
   If a bar only WICKS above without closing above → that wick high
   becomes the new reference high (repeat).
   FLAGGED: "close above then buy stop above the same high" is
   near-tautological — mechanize as: on close above reference high,
   buy stop at reference high + 1 pip (fills next tick unless gapped;
   preserves the stop-order semantics of the source).
5. Pending cancel: zero-line cross-down (campaign end).
6. Exit Method 1 (baseline): SL 1 pip below the breakout signal
   candle's low; TP = 1R (1:1). Method 2 (SL below lower band, 2R) =
   variant; Method 3 (discretionary wedge) = excluded.
7. SELL mirror throughout. One position/pending per magic.

## Inputs

```
strategy_fast_ema = 6
strategy_slow_ema = 17
strategy_bb_period = 10
strategy_bb_shift = 1
strategy_bb_dev = 0.66
strategy_entry_offset_pips = 1.0
strategy_sl_offset_pips = 1.0
strategy_tp_r = 1.0
```

## Hooks sketch

Filter: M5/params/warmup ≥ 40. Entry: false — campaign state machine in
Manage (pending-order house pattern). Manage: state transitions,
pending place/cancel, once-latches. Exit: false. News: default.

Risk note: M5 + 1:1 RR + spread = cost-sensitive (thread's own
criticism, post #7-8); Q02 gross-basis decides. Skeptic posts are part
of the record → falsification candidate, expected weak.
