# STR-012 — Spec reconciliation (claude 01 vs codex 02), 2026-07-24

## Convergent (near-total)
D1 broker bars; wickBuy=O−L vs wickSell=H−O strict comparison, equality → no
order; ONE directional pending per day (not a stop pair); cancel stale
pending at day roll BEFORE placing the new one; one-position policy blocks
new pendings; SL anchored at the LEVEL (prevHigh−30 / prevLow+30 pips), TP
100 pips from planned entry; gap-through-entry → skip the day (no chase);
no ATR filter / no time stop (deliberate difference vs QM5_9959's invented
extras, which died Q04); Sunday-candle sensitivity recorded as evidence
note.

## Deltas
1. **Offsets sourced.** Codex found the author's later restatement fixing
   PipsAboveHigh/BelowLow = 2 pips — claude's "unsourced default 2.0" is
   actually source-backed. Adopted as sourced.
2. **Expiry.** Codex: server-side expiry at next D1 open + explicit cancel
   belt. Claude: expiration_seconds + Manage cancel. Same semantics —
   implement via framework pending expiration + Manage day-roll cancel.
3. Hook placement per fleet convention (position/pending checks in
   EntrySignal/Manage, not NoTradeFilter).
