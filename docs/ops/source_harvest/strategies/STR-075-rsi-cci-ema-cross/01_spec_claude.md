# STR-075 — Claude independent spec (pre-reconciliation)

Source: thread 599061 (ahmedabbas, ~2016). Exec TF H1 (source: H1/H4;
ledger H1). Cohort: EURUSD.DWX, GBPUSD.DWX (the author's named examples).

## Rules

1. EMA(5) and EMA(12) close; RSI(21); CCI(80).
2. LONG: EMA5 crosses above EMA12 on the closed bar (strict edge) AND
   RSI21(1) > 50 AND CCI80(1) > 50 (both strict; the "green candles"
   colour language = the same >50 condition per the indicator paint).
   SHORT mirror (<50 both).
3. SL: the source gives "approximately 35-60 pips" discretionary →
   mechanize input default 50 (mid; flagged). NO fixed TP.
4. EXIT (rule-based, ExitSignal): opposite EMA cross OR both oscillators
   beyond 50 against the position (long exit: EMA5(1)<EMA12(1) OR
   (RSI21(1)<50 AND CCI80(1)<50)); bar-gated level reads.
5. One position; exit-then-fresh-entry (no same-evaluation reversal).

Prior QM5_9958 deltas (codex T6): close-vs-EMA + separation gates, ATR
stop replacement, 1.5R TP, spread veto, 20-bar time exit — all absent.

## Inputs

```
strategy_ema_fast = 5
strategy_ema_slow = 12
strategy_rsi_period = 21
strategy_cci_period = 80
strategy_level = 50.0
strategy_sl_pips = 50.0   // source "35-60 approx" (flagged midpoint)
```

## Hooks sketch

Filter: H1/params/warmup ≥ 90/handles (2×iMA, iRSI, iCCI). Entry: edge +
confirms. Manage: empty. ExitSignal: rule above. News: default.
