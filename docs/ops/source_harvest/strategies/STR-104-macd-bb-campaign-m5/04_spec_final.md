# STR-104 — FINAL reconciled spec (build authority)

EA: QM5_20143 `macd-bb-campaign-m5` · TF M5 · Cohort: EURUSD.DWX,
GBPUSD.DWX.

## Campaign state machine (closed M5 bars)

- macd[i] = EMA(6,close)[i] − EMA(17,close)[i] (≡ MACD(6,17,1)
  zero-line; pooled QM_EMA readers). BB(10, plot-shift 1, dev 0.66,
  close) — buffer reads must be causally aligned (value shown at bar 1
  computed one bar earlier); OnInit self-test verifies alignment.
- NEW_CAMPAIGN: macd[2] ≤ 0 AND macd[1] > 0 → long campaign (mirror
  short). Any opposite zero cross aborts the campaign, cancels the
  pending, resets all state.
- EXTENSION (long): ≥1 closed bar above the upper band after the
  cross; track campaign high from cross bar to the bar before first
  band re-entry.
- PULLBACK (long): Low[1] ≤ aligned upper band (wick contact; close
  may be anywhere).
- BREAKOUT-WAIT (long): a later bar CLOSES strictly above the tracked
  high → BUY STOP at that confirming candle's high + 1 pip. Wick above
  without close → that higher high becomes the new reference.
  If the stop price is behind market / violates stop-freeze geometry
  at placement → record invalid, wait for the next campaign (no market
  chase, no widening).
- One fill per campaign; one pending/position per magic. Pending lives
  until the opposite zero cross (no bar expiry); news blackout cancels
  a triggerable pending (fresh breakout required after).
- SHORT mirror throughout.

## Exits (Method 1 baseline)

- SL = 1 pip beyond the breakout signal candle's opposite extreme;
  TP = exactly 1R (fill→SL distance). R invalid/non-positive → reject.
- A later zero cross does NOT close a filled position (source assigns
  the cross only to unfilled-order cancellation).
- Method 2 (aligned outer-band SL frozen at the signal bar, 2R) =
  labeled variant; Method 3 (wedge) = excluded.

## Inputs

```
strategy_fast_ema = 6
strategy_slow_ema = 17
strategy_bb_period = 10
strategy_bb_shift = 1
strategy_bb_dev = 0.66
strategy_entry_offset_pips = 1.0
strategy_sl_offset_pips = 1.0
strategy_tp_r = 1.0
```

## Flags

- Extension-then-wick-contact pullback (I-03); confirming-candle stop
  anchor (I-04, material); one-fill-per-campaign (I-06); BB applied
  price close (I-01). Expected weak (thread skeptics; M5 + 1:1 cost
  sensitivity) — pure falsification candidate.

## Hooks

Filter: M5/params/warmup ≥ 40. Entry: false — state machine in Manage
(pending house pattern). Manage: transitions, pending place/cancel,
once-latches, per-bar retry pacing. Exit: false. News: default
fail-closed + pending cancel. NO QM_IsNewBar(); own static guards;
ZeroMemory(req) + symbol_slot.
