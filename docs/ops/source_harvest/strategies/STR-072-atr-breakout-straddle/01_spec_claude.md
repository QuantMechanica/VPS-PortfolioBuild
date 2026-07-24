# STR-072 — Claude independent spec (pre-reconciliation)

Source: thread 562470 (abokwaik, ~2015; "ATR Break Out"/ABO). Exec TF H1.
Cohort: EURUSD.DWX (the author's own H1 example symbol; test-design,
flagged).

## Rules

1. ATR(50) on closed H1 bars.
2. At each new H1 bar: DELETE own untriggered pendings, then place a
   fresh straddle: BUY STOP at Open(0) + bo_mult × ATR(1); SELL STOP at
   Open(0) − bo_mult × ATR(1) (the immutable new-bar open is the anchor —
   "calculated ... at the start of new bar"; the only shift-0 read).
3. SL = sl_mult × ATR(1) from entry; TP = tp_mult × ATR(1); trailing stop
   = ts_mult × ATR(1) (ratchet, never widen, per-tick with min-step).
4. Defaults (author-stated in-thread): bo 3, SL 4, TS 6, TP 20.
5. One position; while a position is open no new straddle (pendings
   deleted); the "Multiple Orders = 99" crazy-set variant is
   stacking-class and EXCLUDED (hard rule adjacent).
6. Optional MACD/RSI filters (participant-suggested; the author later
   defaulted RSI filter on in his EA, but the filter PARAMETERS are not
   in the text) → baseline OFF, documented variant (unmechanizable
   without the .ex4 internals; flagged).

## Inputs

```
strategy_atr_period = 50
strategy_bo_mult    = 3.0
strategy_sl_mult    = 4.0
strategy_tp_mult    = 20.0
strategy_ts_mult    = 6.0
```

## Hooks sketch

Filter: H1/params/warmup ≥ 60/handle (iATR). Entry: per-bar straddle
refresh via two-phase state machine (delete in Manage first). Manage:
pending refresh lifecycle + ATR trailing ratchet. Exit: false. News:
default.

## Notes

Prior build QM5_9939 (0.35/1.0/1.5 geometry + mandatory invented filters,
codex T6) not transferable. TP at 20×ATR is far (trend-following; TS is
the realistic exit). Frequency: bo=3 on H1 → sparse (author: "hardly one
trade per week" per symbol on H4@3; H1 more) — floor watch.
