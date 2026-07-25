# STR-120 — FINAL reconciled spec (build authority)

EA: QM5_20146 `london-orb-3candle-h1` · TF H1 · Cohort: EURGBP.DWX,
EURUSD.DWX, GBPJPY.DWX, GBPUSD.DWX (the author's retained four,
00_source.md:420; six-pair incl. USDCHF/USDJPY = labeled variant).

## Day state (UK-DST-aware in-EA, QM5_20119 pattern)

- London open = 08:00 UK-local. Range = high/low (wicks) of the 3
  completed H1 bars opening 05:00/06:00/07:00 UK-local. Missing bars
  or non-positive range → date blocked, evidence logged.
- Entry evaluation from the 08:00 bar onward, closed bars only.

## Entry / exits

- First H1 CLOSE strictly beyond a border → market entry next tick
  (wick-only or exactly-on-border ≠ signal). The first qualifying
  close CONSUMES the date even if a gate rejects the order.
- SL at the opposite range border; reject invalid geometry. TP = 1.5 ×
  (fill→SL distance) from fill.
- Time exit: 16:45 America/New_York (DST-aware; grounded in the
  author's 6:45 AM AEST close routine ≈ pre-17:00-ET close; FLAGGED
  interpretation, input). No new entries at/after the cutoff.
- ONE filled trade per symbol/UK-date; no re-entry, no reverse. No
  trailing, no BE, no partials, no range-size/buffer filters
  (FLAG-120-02/03/04 exclusions).

## Inputs

```
strategy_london_open_uk_hour = 8
strategy_range_bars = 3
strategy_tp_r = 1.5
strategy_close_ny_hour = 16
strategy_close_ny_min = 45
```

## Hooks

Filter: H1/params/warmup + UK/US DST helpers. Entry: false — day state
machine in Manage (close-confirmed market entry, one-per-day latch,
time exit with per-bar retry). Manage: as above. Exit: false. News:
default fail-closed (in-blackout signal = skipped, not re-armed). NO
QM_IsNewBar(); own static guards; ZeroMemory(req) + symbol_slot.
