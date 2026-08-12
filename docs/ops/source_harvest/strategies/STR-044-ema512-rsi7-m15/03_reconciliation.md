# STR-044 — Reconciliation (2026-07-24)

Convergent: EMA5/12 close-cross edge on closed bars + RSI7 vs 50 strict;
next-bar entry; one position; SL 20 pips fixed (OP's first-stated option;
prev-candle-extreme variant documented, unbuilt); no session filter
(implementer's window = variant). Conflict: TP — claude 20 (range
midpoint) vs codex 25 (selected from the OP's 10-30 range via the p.24
in-thread implementer precedent). RESOLVED → codex 25 (in-thread-sourced
beats arbitrary midpoint; flagged). RSI7 stays (implementer's RSI5 does
not supersede the OP). EURUSD.DWX single-symbol cohort (OP-explicit).
Overlap QM5_9701 verified distinct.

## Addendum (bulk-audit 2026-07-24)

Rebuild justification vs QM5_9701 made CONCRETE: 9701 added an unsourced
spread filter (spread < 20% of ATR(14)) and a session gate (broker
08:00-18:00) — neither appears in the OP baseline. QM5_20116 carries the
bare OP rules (no spread/session filters); 9701's Q02/Q04 outcomes are not
transferable.
