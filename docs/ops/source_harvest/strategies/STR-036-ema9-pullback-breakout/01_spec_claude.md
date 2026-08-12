# STR-036 — Claude independent spec (pre-reconciliation)

Source: thread 242787 "Simple 1 EMA strategy on M15" (Feliks, ~2010). Exec
TF M15. Symbol: GBPUSD.DWX (the author's stated test pair; single-symbol
cohort — source names no others).

## Core rules (Feliks' definitive post, mechanized bar sequence)

Bars: A = shift 2 (the "previous candle"), B = shift 1 (the "second
candle" = signal bar). All closed-bar reads; EMA(9) close, M15.

BUY iff:
1. Close(B) > EMA9(B) AND Close(A) > EMA9(A) is NOT required — the source's
   "price close above 9EMA" = the prevailing side; mechanize minimally:
   Close(B) > EMA9(B).
2. Low(B) − EMA9(B) ≥ 5 pips (the pullback keeps a gap off the MA).
3. Close(B) > High(A) (the signal bar closes beyond the prior bar's
   extreme).
Enter market at next bar. SL = Low(A) − 1 pip − spread (mechanize spread =
current spread at entry, floor 0; flagged). TP = entry + 2 × (entry − SL).
SELL mirror (source has a copy-paste typo "under previous candle's high" —
read as ABOVE prev high + 1 pip + spread; flag verbatim).

One position; no re-entry while open; no session filter (source none).

## Inputs

```
strategy_ema_period   = 9
strategy_min_gap_pips = 5.0
strategy_sl_buffer_pips = 1.0
strategy_rr           = 2.0
```

## Hooks sketch

Filter: M15/params/warmup ≥ 14+5, handle valid. Entry: sequence above, own
new-bar guard. Manage: empty. Exit: false. News: default.

## Notes

- Candle-indexing ambiguity ("price close above" vs bar roles) is THE
  reconciliation point — codex's blind reading decides jointly.
- Overlap QM5_9705 (ledger) — verify distinction (earlier EMA-pullback
  family build).
- Thread died without follow-up (R1 honesty); author withheld "another
  rules" privately → PARTIAL-risk noted but the stated ruleset is complete.
- Frequency: M15 GBPUSD pullback pattern ~100-200/yr.
