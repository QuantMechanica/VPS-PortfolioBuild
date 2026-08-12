# STR-035 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_london-box-fib-straddle` · TF M15 · Symbols (slots 0-4):
EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX, USDCHF.DWX. Base:
EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_box_start_utc_hour = 3;
input int    strategy_box_end_utc_hour   = 6;
input double strategy_entry_ext_pct      = 32.6;  // midpoint of "27-38.2" (flagged; 27.0/38.2 variants)
input double strategy_max_box_pips       = 40.0;  // restrictive end of "40-50"
```

## Daily cycle (UTC via QM_BrokerToUTC; own static latches)

1. At the first new M15 bar with UTC-open ≥ box end (once per UTC day):
   box H/L over closed M15 bars with UTC-open ∈ [start, end). Veto: box
   size > max_box_pips (log SETUP_CONFIG_INVALID reason=box_too_big; date
   blocked). Offset = ext_pct% × box size. BUY STOP @ H+offset (SL = L),
   SELL STOP @ L−offset (SL = H), TP = entry ± box size. Both legs valid or
   date blocked (no one-sided straddle; 20107 convention). Two-phase
   placement state machine. Expiration: next box start.
2. Manage per tick: if own position exists and the opposite pending is
   alive → delete it (one trade at a time). At UTC box start: flatten own
   positions (STRATEGY_EXIT reason=box_reset) + delete pendings.
3. Option A: one filled trade per box (no re-arm; option B variant is
   card-documented, disabled).

## Hooks

1 NoTradeFilter: M15; params (0≤h<24, start<end, ext>0, cap>0); warmup ≥ 1
day. 2 EntrySignal: cycle above. 3 Manage: above. 4 ExitSignal: false.
5 NewsFilterHook: default.

## Compliance

Registry magic (5 slots); RISK_FIXED/RISK_PERCENT; ≤1% per trade (sized off
the box-width SL); no martingale (source musings NOT built — hard rule);
frequency ~200 boxes/yr (floor safe).
