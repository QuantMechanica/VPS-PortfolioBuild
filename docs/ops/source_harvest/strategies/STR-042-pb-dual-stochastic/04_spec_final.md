# STR-042 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_pb-dual-stoch-m15` · TF M15 · Symbol (slot 0): EURUSD.DWX.
Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_green_k            = 72;
input int    strategy_red_k              = 285;
input int    strategy_red_slowing        = 246;
input double strategy_level_low          = 24.0;
input double strategy_level_high         = 76.0;
input int    strategy_atr_period         = 14;
input double strategy_emergency_atr_mult = 4.0;  // unsourced house protection (flagged)
```

## Rules (all closed-bar shifts 1/2; strict inequalities; doji = neither
## colour; equality = no signal; next-bar action)

green = %K of iStochastic(72,1,1); red = %K of iStochastic(285,1,246).
LONG: green(1)>red(1) AND green(1)>24 AND both bars 1,2 bearish.
CLOSE LONG (ExitSignal): green(1)<red(1) AND both bars bullish.
SHORT: green(1)<red(1) AND green(1)<76 AND both bars bullish.
CLOSE SHORT: green(1)>red(1) AND both bars bearish.
One position; no reversal-in-place (fresh entry requires flat + its own
conditions). Emergency SL = 4×ATR(14) at entry, never moved; no TP.

## Hooks

1 Filter: M15/params/warmup ≥ 285+246+10/handles. 2 Entry: above.
3 Manage: empty. 4 ExitSignal: close rules (bar-gated). 5 News: default.

## Compliance

Registry magic slot 0; RISK_FIXED at the emergency stop; ≤1%/trade;
teaching-example provenance recorded; frequency est. 150-300/yr.
