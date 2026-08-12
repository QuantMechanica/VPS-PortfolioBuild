# STR-072 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_abo-atr-straddle-h1` · TF H1 · Symbol (slot 0): EURUSD.DWX.
Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_atr_period = 50;
input double strategy_bo_mult    = 3.0;
input double strategy_sl_mult    = 4.0;
input double strategy_tp_mult    = 20.0;
input double strategy_ts_mult    = 6.0;
```

## Cycle (per new H1 bar; own guard)

1. Manage (first in OnTick): delete own untriggered pendings from the
   PREVIOUS bar (TM_REMOVE_PENDING reason=bar_refresh); on a fill, delete
   the opposite pending (OCO).
2. EntrySignal: if no own position: atr = ATR(1); place BUY STOP at
   Open(0)+3.0×atr (SL entry−4.0×atr, TP entry+20.0×atr) then SELL STOP
   mirror via the two-phase state machine (one request per call);
   expiration = next bar. Gap-through → skip that side.
3. Manage trailing: with a position, candidate SL = price ∓ 6.0×atr_now
   (atr at the last closed bar); ratchet only (never widen), min-step 1
   point, stops-level-legal, per-tick.

## Hooks

1 Filter: H1/params/warmup ≥ 60/handle. 2 Entry: straddle machine.
3 Manage: refresh/OCO/trail. 4 Exit: false. 5 News: default.

## Compliance

Registry magic slot 0; RISK_FIXED off the 4×ATR SL; ≤1%/trade; filters
false (unrecoverable params — variant); Multiple-Orders set EXCLUDED
(stacking); sparse frequency (bo=3) — floor watch (below-floor Q02 =
RETIRE).
