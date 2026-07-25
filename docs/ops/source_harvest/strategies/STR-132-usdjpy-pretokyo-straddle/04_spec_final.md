# STR-132 — FINAL reconciled spec (build authority)

EA: QM5_20148 `usdjpy-pretokyo-straddle` · TF M15 · Cohort: USDJPY.DWX.

## Day state (ET-civil, DST-aware via QM_DSTAware US helper)

- Range: high/low (wicks) of the 8 completed M15 bars opening
  [18:00, 20:00) ET. Incomplete bars / non-positive range → date
  blocked + evidence.
- At 20:00 ET: buy stop = range_high + 2.0 pips, sell stop =
  range_low − 2.0 pips (JPY pip = 10*_Point), normalized outward.
  Place BOTH sides only if both + their stops are simultaneously
  legal (never a one-sided straddle). Blackout intersecting
  [20:00, 22:00) ET → block the date.
- 22:00 ET: unfilled pendings deleted, date no-trade.

## Position (netted; one position per magic)

- First fill cancels the sibling immediately (OCO projection,
  FLAG-132-03/05; simultaneous double-fill = anomaly → flatten the
  later fill, block date, log evidence).
- SL = 15.0 pips + spread captured at pending placement (never
  widened later; on-fill snapshot = variant). Volume must split into
  two legal halves after step normalization — else reject the date
  (the 50/50 split IS the payoff structure).
- TP1: close 50% of original volume at ±40 pips (once-latch, retry
  pacing, QM_EXIT_PARTIAL). No SL move before TP1 confirmed.
- After TP1: runner SL → exact break-even (+0; +1 pip = labeled
  variant), runner TP ±70 pips.
- No time exit for filled positions (the cutoff governs entry only);
  no re-entry/reverse per ET date; skip a new date while positioned.
- State reconstruction from deal history on restart (idempotent
  partial/BE transitions).

## Inputs

```
strategy_range_start_et_hour = 18
strategy_range_end_et_hour = 20
strategy_entry_cutoff_et_hour = 22
strategy_entry_offset_pips = 2.0
strategy_sl_pips = 15.0
strategy_sl_add_spread = true
strategy_tp1_pips = 40.0
strategy_tp1_fraction = 0.50
strategy_tp2_pips = 70.0
strategy_be_plus_pips = 0.0
```

## Overlap

Materially distinct from QM5_20107 (STR-016) and live QM5_9936 —
codex 02 §7 table (clock/offset/stop/payoff all differ); retained as
distinct candidate.

## Hooks

Filter: M15/params + ET conversion. Entry: false — straddle state
machine in Manage (range build, OCO place/cancel at ET anchors,
TP1-half once-latch, BE move, retry pacing). Manage: as above. Exit:
false. News: default fail-closed + pending removal. NO QM_IsNewBar();
own static guards; ZeroMemory(req) + symbol_slot.
