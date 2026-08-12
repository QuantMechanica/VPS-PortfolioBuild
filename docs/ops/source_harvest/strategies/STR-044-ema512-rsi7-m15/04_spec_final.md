# STR-044 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_ema512-rsi7-m15` · TF M15 · Symbol (slot 0): EURUSD.DWX.
Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_ema_fast   = 5;
input int    strategy_ema_slow   = 12;
input int    strategy_rsi_period = 7;
input double strategy_rsi_level  = 50.0;
input double strategy_tp_pips    = 25.0;  // in-thread implementer selection from OP's 10-30 (flagged)
input double strategy_sl_pips    = 20.0;  // OP's fixed option (prev-candle variant unbuilt)
```

## Rules

LONG: ema5(1)>ema12(1) AND ema5(2)<=ema12(2) AND rsi7(1)>50 (strict);
SHORT mirror. Next-bar entry; SL/TP fixed pips; one position; no reversal.

## Hooks

1 Filter: M15/params/warmup ≥ 20/handles (2×iMA+iRSI). 2 Entry: above.
3 Manage: empty. 4 Exit: false. 5 News: default.

## Compliance

Registry magic slot 0; RISK_FIXED/RISK_PERCENT; ≤1%/trade; churn ~300+/yr
judged by Q02; falsification build.
