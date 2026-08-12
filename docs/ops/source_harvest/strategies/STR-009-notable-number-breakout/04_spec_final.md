# STR-009 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_notable-number-breakout-m5` · TF M5 · Symbol (slot 0):
CADJPY.DWX. Base: `framework/templates/EA_Skeleton.mq5`. Same lattice/
trigger/latch machinery as STR-008's final spec with MIRRORED polarity;
separate EA identity (both blind specs independently required it).

## Inputs (group "Strategy"; defaults = CADJPY row)

```
input string strategy_notable_suffix     = "88";
input int    strategy_lookback_d1_bars   = 41;
input double strategy_sl_price_pct       = 0.75;
input double strategy_tp_price_pct       = 1.00;
input int    strategy_window_start_hhmm  = 1400;  // broker clock (source "London+2h" ≡ broker)
input int    strategy_window_end_hhmm    = 2200;
```

## Entry (continuation — inverse gates)

Open-to-open crossing as STR-008, but:
- ascending crossing (prev<cur), candidate = LOWEST crossed level:
  **BUY** iff max(High(D1,1..N)) < level (N days wholly BELOW, breakout up).
- descending crossing, candidate = HIGHEST crossed level:
  **SELL** iff min(Low(D1,1..N)) > level (mirror).
One-fire latch identical. SL/TP percent-of-fill identical. One position.

## Hooks

Identical structure to STR-008 (filter: M5/params/warmup 41+2 D1 bars;
EntrySignal owns window/position/latch; Manage empty; ExitSignal false;
NewsFilterHook default).

## Compliance

Registry magic slot 0; RISK_FIXED/RISK_PERCENT; ≤1%/trade. Frequency floor
risk EXPLICIT: single sparse setup — a below-floor Q02 verdict RETIREs it
(economics rule); built as the faithful falsification of the family's only
distinct un-built mechanic.
