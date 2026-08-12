# STR-038 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_ema369-cross-m5` · TF M5 · Symbols (slots 0-1): EURUSD.DWX,
GBPUSD.DWX (test-design cohort, flagged). Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_ema_fast = 3;
input int    strategy_ema_mid  = 6;
input int    strategy_ema_slow = 9;
input double strategy_tp_pips  = 10.0;  // author's pip approximation of his 2.5%-balance TP (flagged)
input double strategy_sl_pips  = 20.0;
```

## Entry / exit

Full-condition edge on closed bars: LONG iff (ema3>ema6 AND ema3>ema9) at
shift 1 AND NOT at shift 2; SELL mirror. Entry next bar; SL/TP fixed pips.
ExitSignal: opposite full-cross LEVEL condition on shift 1 (bar-gated
internal read) closes the open position; after an opposite-cross close the
mirrored entry may fire only on a FRESH edge (no same-evaluation reversal).
One position.

## Hooks

1 NoTradeFilter: M5; params; warmup ≥ 14; three iMA handles valid.
2 EntrySignal: above. 3 Manage: empty. 4 ExitSignal: above.
5 NewsFilterHook: default.

## Compliance

Registry magic (2 slots); RISK_FIXED/RISK_PERCENT; ≤1%/trade; extreme
M5 churn expected — Q02 judges; falsification build.
