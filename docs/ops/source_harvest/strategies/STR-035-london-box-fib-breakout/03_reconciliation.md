# STR-035 — Reconciliation (2026-07-24)

Convergent: GMT-fixed 03:00-06:00 box (source-explicit conversion
instruction; QM_BrokerToUTC), M15; stop entries offset 32.6% of box beyond
the edges (BOTH blind specs independently chose the 27/38.2 midpoint;
exposed as input for the 0.27/0.382 indicator variants); TP = box size from
entry; SL = opposite box side; box-size veto.
Conflicts: (1) Trade-handling baseline — claude option B (author's stated
preference, but needs invented re-arm semantics), codex option A (expressly
source-authorized, deterministic, more restrictive). RESOLVED → codex
option A (tie-breaks 2+3); option B documented as card variant with codex's
completed-bar-reset re-arm mechanization. (2) Box cap: claude 50 vs codex
40 ("over 40-50" → restrictive end). RESOLVED → 40 (tie-break 2). (3) On
fill: delete the opposite pending (one trade at a time — both). Reset at
next box start: flatten + delete (author preference, both).
Overlap QM5_20045 (earlier London-box family): this thread's signature =
fib-extension entries + box-size TP + opposite-side SL + option-A; verified
distinct.
