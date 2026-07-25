# STR-132 — Claude independent spec (pre-reconciliation)

Source: babypips thread 38113 (marvindoriot, 2011). Exec TF M5
(range/trigger granularity; source is time-window based). Cohort:
USDJPY.DWX (source-exclusive pair).

## Rules

1. Range window: 18:00–20:00 NEW YORK LOCAL (the author's "6 pm to
   8 pm EASTERN"; his "22:00-0:00 GMT" equivalence is the EDT case —
   the ET anchor governs, DST-aware via the QM_DSTAware US helper).
   Record range high/low.
2. Straddle: BUY STOP at high + 2.0 pips, SELL STOP at low − 2.0 pips
   (source: "exactly 2.0").
3. Entry window: pendings live only until 22:00 NY-local ("if not
   broken by 10 pm EST DO NOT ENTER") → cancel both at 22:00 ET.
4. Split position (netted, 20101/20098 machinery): logical halves.
   SL 15 pips + current spread (source-explicit "+ SPREAD") on the
   whole position. TP1 = 40 pips on half; at TP1 fill → move the
   remainder's SL to BE+1 (no SL move before TP1). TP2 = 70 pips on
   the remainder.
5. Opposite pending after a fill: the source is NOT OCO (thread #8
   shows both sides triggering on 4/20, hedging account). House
   netting → mechanize OCO-cancel on fill (bounded projection,
   FLAGGED; stop-and-reverse would be an unsourced amplification).
6. One campaign per day; no re-arm after the position closes. Day
   state resets at the next 18:00 ET.
7. ~10% of nights: no trade (no break by 22:00) — expected behavior.

## Inputs

```
strategy_range_start_ny_hour = 18
strategy_range_end_ny_hour = 20
strategy_entry_cutoff_ny_hour = 22
strategy_trigger_offset_pips = 2.0
strategy_sl_pips = 15.0
strategy_sl_add_spread = true
strategy_tp1_pips = 40.0
strategy_tp2_pips = 70.0
strategy_be_plus_pips = 1.0
```

## Hooks sketch

Filter: M5/params. Entry: false — straddle state machine in Manage
(range build, pending place/cancel at ET anchors, TP1-half close
once-latch, BE move, retry pacing). Exit: false. News: default +
pending cancel.

## Overlap analysis (mandatory)

QM5_20107 asian-range-straddle-m15 (STR-016): Asian-session range with
broker-clock windows, different range window and no split-TP/BE
ladder. QM5_9936 (live H1 straddle): different window/TF family.
STR-132's 2-hour pre-Tokyo ET-anchored mini-range + 2-pip trigger +
40/70 split + BE-after-TP1 is materially distinct — reconciliation
must confirm against both SPECs.
