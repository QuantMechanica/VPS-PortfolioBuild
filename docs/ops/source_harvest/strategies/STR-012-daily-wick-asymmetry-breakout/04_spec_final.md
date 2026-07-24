# STR-012 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_daily-wick-stop-breakout` · TF D1 · Symbols (slots 0–4):
EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, EURAUD.DWX. Base:
`framework/templates/EA_Skeleton.mq5`. Faithful-variant rationale: QM5_9959
(same thread) added an ATR range filter + next-open time stop and FAILED Q04;
this build = the OP's bare 12-point v3 ruleset.

## Inputs (group "Strategy")

```
input double strategy_pips_above_high = 2.0;   // author restatement (sourced)
input double strategy_pips_below_low  = 2.0;
input double strategy_sl_pips         = 30.0;  // author's profitable settings
input double strategy_tp_pips         = 100.0;
```

## Day-roll transaction (once per new broker D1 bar; own static guard)

1. Manage hook (runs first in OnTick): cancel own still-pending order whose
   tagged source-D1 time < current shift-1 bar time
   (`TM_REMOVE_PENDING reason=day_roll`).
2. EntrySignal (new-D1 gate): if own POSITION exists → false (one exposure;
   pending replaced daily, position never stacked).
   Read O/H/L = D1 shift 1. wick_buy = O−L; wick_sell = H−O; equal → false.
   wick_buy > wick_sell → BUY STOP: entry = H + 2 pips; SL = H − 30 pips;
   TP = entry + 100 pips. Mirror for SELL STOP at L − 2 / SL L + 30 /
   TP entry − 100.
   Validation: normalize to tick; stops-level/freeze check; if market has
   already gapped beyond the planned entry → skip day (no chase, log
   SETUP_CONFIG_INVALID reason=gap_through_entry). Pending request via
   framework pending path, expiration_seconds = seconds to next D1 open
   (belt: Manage cancel above). Tag request comment/state with source-D1
   time.

## Hooks 3–5

Manage: only the day-roll pending cancel (per-tick guard on new-D1 edge with
own static). ExitSignal: false (server SL/TP). NewsFilterHook: framework
default.

## Compliance

Registry magic (5 slots); RISK_FIXED backtest / RISK_PERCENT live sized from
planned-entry→SL distance; ≤1%/trade; R1 honesty (OP: live "hits stop loss
everytime", tester-vs-live divergence warned, ChatGPT-genesis) recorded —
built for faithful falsification on real ticks; Sunday-candle dataset
identity recorded in evidence (source reports result sensitivity).
Frequency: ~150-250 pendings/yr/symbol, fill fraction unknown — floor safe.
