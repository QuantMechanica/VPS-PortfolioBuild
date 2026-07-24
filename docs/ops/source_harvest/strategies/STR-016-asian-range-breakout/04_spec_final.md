# STR-016 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_asian-range-straddle-m15` · TF M15 · Symbol (slot 0):
USDJPY.DWX. Base: EA_Skeleton. Competing variant of live QM5_9936 (H1);
ledger-validated distinctness (M15 range resolution + M15-bar trail).

## Inputs (group "Strategy"; broker-clock HHMM ints)

```
input int strategy_range_start_hhmm   = 100;
input int strategy_range_end_hhmm     = 600;
input int strategy_cancel_hhmm        = 1300;  // literal source clock; "1.5h before NY" inconsistency flagged
input int strategy_flat_hhmm          = 2000;
```

## Daily cycle (all broker time; own static day/state latches)

1. **Arm (EntrySignal):** at the first new M15 bar with open ≥ range end and
   before cancel time, once per day: range = max High / min Low over the
   completed M15 bars with open ∈ [start, end). Validate: both stops legal
   (tick/stops-level/positive risk), NEITHER boundary already crossed by
   current quotes — else block the DATE (no one-sided straddle, log
   SETUP_CONFIG_INVALID reason=straddle_invalid). Place via two-phase state
   machine (EntrySignal returns one request per call): phase BUYSTOP → next
   call SELLSTOP → DONE. BUY STOP @ high (SL = low), SELL STOP @ low
   (SL = high), TP = 0, expiration_seconds → cancel time.
2. **Fills:** opposite pending STAYS (max 2 entries/day — the second fill
   only via the first position's stop-out at the shared border level).
3. **Manage (per tick):** at ≥ cancel time: delete own pendings
   (TM_REMOVE_PENDING reason=cancel_window). At ≥ flat time: close own
   positions (STRATEGY_EXIT reason=session_flat). Per NEW closed M15 bar:
   trail long SL to max(SL, Low(1)); short SL to min(SL, High(1)); never
   widen; stops-level-legal only.
4. New day (day-key change): reset latches.

## Hooks

1 NoTradeFilter: M15; params (0≤hhmm<2400, start<end<cancel<flat); warmup
≥ 1 trading day of M15 bars. 2 EntrySignal: as above. 3 Manage: as above.
4 ExitSignal: false. 5 NewsFilterHook: default.

## Compliance

Registry magic slot 0; RISK_FIXED/RISK_PERCENT convention; ≤1%/trade per
side (each sized off its own border SL); news gate blocks placement in
windows (pendings placed earlier persist — framework behaviour, documented);
frequency ~250 straddles/yr (floor safe). Restart: replay day state from
clock + own orders/positions (no files).
