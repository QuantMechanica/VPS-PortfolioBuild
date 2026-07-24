# STR-069 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_dailyopen-h1-basket` · TF H1 · BASKET: host EURUSD.DWX
(chart), members slot 0 = EURUSD.DWX, slot 1 = GBPUSD.DWX. host_symbol
REQUIRED in card/sets (Q08). Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input double strategy_sl_pips        = 10.0;
input double strategy_tp_pips        = 10.0;
input double strategy_basket_tp_pips = 10.0;  // COMBINED floating pips (codex-resolved)
```

## Daily cycle

1. EntrySignal (own day latch; two-phase state machine, one request per
   call): at the close of the FIRST H1 bar of the broker day, for each
   member independently: H1 close(1) > that symbol's D1 open → BUY;
   < → SELL; equality skips that member. req.symbol_slot set per member;
   SL/TP 10/10 pips in the member symbol's pip size.
2. Manage (per tick): while BOTH member positions are open, compute
   combined floating profit in pip-equivalents (per-symbol pip value);
   >= basket_tp_pips → close BOTH at market (STRATEGY_EXIT
   reason=basket_tp; once-latch + per-bar retry pacing on rejection).
3. No other exits (server SL/TP; Friday close framework). One evaluation
   per day; positions may carry.

## Hooks

1 Filter: H1/params/warmup >= 2 days (both members' history present).
2 Entry: cycle above. 3 Manage: basket close. 4 Exit: false. 5 News:
default (gates placement per host; member requests inherit framework
news gating).

## Compliance

Registry magic (2 slots, one per member); RISK_FIXED per leg (<=1% each);
basket coupling documented; host_symbol in sets; frequency ~250 eval
days/yr × up to 2 legs — churn judged by Q02. Prior build QM5_10049
(uncoupled) not transferable.
