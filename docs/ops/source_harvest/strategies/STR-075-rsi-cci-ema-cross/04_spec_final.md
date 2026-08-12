# STR-075 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_ema-rsi-cci-h1` · TF H1 · Symbols (slots 0-1): EURUSD.DWX,
GBPUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_ema_fast   = 5;
input int    strategy_ema_slow   = 12;
input int    strategy_rsi_period = 21;
input int    strategy_cci_period = 80;
input double strategy_level      = 50.0;
input double strategy_sl_pips    = 50.0;  // source range 35-60 (neutral default)
```

## Rules

LONG iff ema5 crosses above ema12 on the closed bar (strict edge: >
at 1, <= at 2) AND rsi21(1) > 50 AND cci80(1) > 50 (strict). SHORT
mirror. Entry next bar; SL 50 pips server-side; TP none. One position.
ExitSignal (bar-gated): long open AND (ema5(1) < ema12(1) OR (rsi21(1) <
50 AND cci80(1) < 50)) → close; short mirror. No same-evaluation
reversal (fresh entry needs its own edge).

## Hooks

1 Filter: H1/params/warmup >= 90/handles. 2 Entry: above. 3 Manage:
empty. 4 ExitSignal: above. 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED off the 50-pip SL; <=1%/trade;
frequency est. 80-150/yr/symbol.
