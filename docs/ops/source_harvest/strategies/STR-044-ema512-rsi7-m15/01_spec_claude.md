# STR-044 — Claude independent spec (pre-reconciliation)

Source: thread 316055 (sashadeol OP; p.24 cTrader implementer variant
recorded). EURUSD.DWX M15 (OP: "M15 EURUSD; other currencies at your own
risk" → single-symbol cohort).

## Rules (OP baseline)

- EMA(5) and EMA(12) close; RSI(7).
- LONG: EMA5 crosses above EMA12 on closed bar (ema5(1)>ema12(1) AND
  ema5(2)<=ema12(2)) AND RSI7(1) > 50 (strict). SHORT mirror (RSI < 50).
- Entry next bar open. One position; no reversal.
- SL: 20 pips (the OP's first-stated fixed option; prev-candle-extreme
  variant documented, unbuilt). TP: 20 pips (midpoint of the OP's "10-30
  pips" range — flagged mechanization; the p.24 implementer used 25/25 —
  codex counter-proposal welcome).
- No session filter in the OP (the p.24 16:00-21:45-GMT window is the
  implementer's variant, unbuilt).

## Inputs

```
strategy_ema_fast = 5
strategy_ema_slow = 12
strategy_rsi_period = 7
strategy_rsi_level = 50.0
strategy_tp_pips = 20.0
strategy_sl_pips = 20.0
```

## Hooks sketch

Filter: M15/params/warmup ≥ 20/handles (2×iMA + iRSI). Entry: cross+RSI
(own guard). Manage: empty. Exit: false. News: default.

## Notes

- Overlap QM5_9701 — verify distinction.
- TP mechanization (20 vs 25) = reconciliation point.
- M15 EMA5/12 churn high (~300+/yr); falsification build.
