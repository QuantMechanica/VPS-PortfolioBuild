# STR-088 — Claude independent spec (pre-reconciliation)

Source: thread 932507 (foff00, ~2019). Exec TF H4 (author: "I trade on
4H chart"; his later M15-scalper drift = variant, not baseline).
Cohort: EURUSD.DWX, GBPUSD.DWX (author names no pairs; test-design,
flagged).

## Rules

1. EMA(25, close) on M15, H1, H4, D1 (author-confirmed: same period on
   all four TFs). ATR(14) on H4 (the execution chart; "I only use
   ATR(14) and 25EMA" on the 4H — flagged).
2. LONG: the last closed bar of EVERY TF (M15/H1/H4/D1) closes above
   its 25EMA. Evaluated once per closed H4 bar (execution anchor).
   SHORT mirror (all below).
3. "with closed bars(1-3)": ambiguous — mechanize as a confirmation
   count input (default 1 = the minimal reading: the condition on the
   last closed bar; 2-3 = sweep). FLAGGED.
4. Session gate: entries only after London open and none after NY
   close — mechanize: broker-clock window [London open, NY close)
   using the NY-close broker convention (London open = 09:00 broker
   summer-invariant? -> anchor via QM_BrokerToUTC at 07:00 UTC London
   open equivalent; FLAGGED, the author gives no precise hours).
   Management runs 24h.
5. SL = 2×ATR(14,H4) from entry; TP = 3×ATR (the "3-4×" range's
   restrictive end; 4× = variant). One position per magic; re-entry
   only after flat + fresh evaluation.
6. No trailing in the core post (the later "trailing stop" remark is
   the M15 EA drift — excluded).

## Inputs

```
strategy_ema_period = 25
strategy_atr_period = 14
strategy_confirm_bars = 1
strategy_sl_atr = 2.0
strategy_tp_atr = 3.0
strategy_session_start_utc = 7
strategy_session_end_utc = 21
```

## Hooks sketch

Filter: params/warmup (D1 EMA needs ~50 D1 bars) + handles on 4 TFs.
Entry: MTF alignment check, closed bars only (shift 1 per TF). Manage:
none beyond framework. Exit: false. News: default.

Overlap note: QM5_20097 three-little-pigs is MTF-SMA(W1/D1/H4)
stacking-based — different TF set, different MA, different entry logic;
QM5_20121 MTF-RSI(2) is oscillator-based. No duplicate.
