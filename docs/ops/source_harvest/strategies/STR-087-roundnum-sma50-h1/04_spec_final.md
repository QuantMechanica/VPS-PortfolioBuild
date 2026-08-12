# STR-087 — FINAL reconciled spec (build authority)

EA: QM5_20140 `roundnum-sma50-h1` · TF H1 · Cohort: GBPUSD.DWX,
EURJPY.DWX (source verbatim, 00_source.md:69; EURJPY history 2017-2026
verified).

## Setup (closed-bar, once per new H1 bar)

- Regime: close[1] > SMA50[1] → long; < → short; equal → none.
  SMA: iMA(50, MODE_SMA, PRICE_CLOSE).
- Grid: levels at integer multiples of 25 pips (endings .000/.250/
  .500/.750).
- Long: nearest level L above with L + 3 pips > Ask AND L > SMA50[1]
  AND |L − SMA50[1]| ≥ strategy_ma_proximity_pips → buy stop at
  L + 3 pips. Short mirror: sell stop at L − 3 pips (L below Bid and
  below SMA, distance gate).
- One pending OR position per magic/symbol.

## Risk / exits

- SL 30 pips, TP 50 pips from fill.
- BE ratchet: at +10 pips favorable, move SL once to entry ± 1 pip
  (tighten-only, freeze-level-aware, retry per bar while valid).
- Pending cancel ONLY on: regime flip at H1 close, geometry loss (line
  no longer forward of market), proximity-gate failure, replacement by
  newly nearest eligible line, news gate. NO bar-count expiry.
- Post-exit: next closed-bar evaluation decides fresh setup; no
  auto-reverse, no same-tick re-entry ("wont buy straight away").
- Excluded (unsourced, QM5_10039 contest deltas): 3-bar expiry, 10-bar
  time exit, spread veto, opposite-grid gate.

## Inputs

```
strategy_sma_period = 50
strategy_grid_pips = 25.0
strategy_entry_offset_pips = 3.0
strategy_sl_pips = 30.0
strategy_tp_pips = 50.0
strategy_ma_proximity_pips = 10.0   // PROVISIONAL projection; sweep {5,15}
strategy_be_trigger_pips = 10.0
strategy_be_plus_pips = 1.0
```

## Flags

- MA-proximity default = projection (no source number) — 03 #2.
- Sideways 25/25 mode, MA200/EMA, H4/D1-100-pip family = variants.

## Hooks

Filter: H1/params/warmup ≥ 60. Entry: returns false — pending state
machine in manage (stop-order house pattern). Manage: regime + nearest-
line selection + pending place/re-point/cancel + BE once-latch with
per-bar retry. Exit: false. News: default fail-closed. NO QM_IsNewBar();
own static guards; ZeroMemory(req) + symbol_slot. JPY pip size from
symbol digits (EURJPY 3-digit → pip = 10*_Point).
