# STR-024 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_ema144-displaced-breach-m5` · TF M5 · Symbols (slots 0–2):
EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX (cohort = test-design, not source; incl.
QM5_9944's failed symbols for comparability). Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_entry_ema_period = 34;
input int    strategy_entry_ema_shift  = 16;
input int    strategy_stop_ema_period  = 144;
input double strategy_tp_pips          = 17.0;
```

## Entry (variant 1 baseline; variant 2 = card-documented, unbuilt)

One unshifted EMA34 handle; trig(s) = buffer[s + shift]. EMA144 handle at
shift 1. Own new-bar guard. No own position. LONG iff close(1) > trig(1)
AND close(2) <= trig(2) (strict cross; equality on prior bar allowed as
"on"); SHORT mirror. SL = EMA144(1) value normalized (wrong side / stops-
level violation → skip + SETUP_CONFIG_INVALID reason=stop_geometry). TP =
entry ± 17 pips (framework pip helper). One position; no reversal.

## Hooks

1 NoTradeFilter: M5; params; warmup ≥ 144+16+5 bars; handles/BarsCalculated.
2 EntrySignal: above. 3 Manage: empty. 4 ExitSignal: false.
5 NewsFilterHook: default.

## Compliance

Registry magic (3 slots); RISK_FIXED sizing off the variable EMA144
distance; ≤1%/trade; R1 honesty (thread's own skepticism, author's serial
strategies) in card — falsification build; churn (M5 crosses, hundreds/yr)
judged by Q02.
