# STR-137 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

H4 only (lower TFs excluded per author warning); EMA20/50 close;
Stoch(14,3,1) SMA CLOSE/CLOSE (the author's "regular settings applied
to the close"); armed-state machine with cancel on EMA recross;
first-hook-only consumption (STR137-I4 ≙ Claude's one-per-arm);
initial HARD server stop 10 pips beyond the impulse start — the
author's mental-stop/no-exit doctrine (−350 pips, p.7) is inadmissible
and replaced (both specs, labeled deviation STR137-D1); fib ladder
{1, 1.272, 1.618, 2, 2.618, 3, 3.618, 4, 4.618, 5}, BE at the first
F(1) close, stop → F(n−1) after a close beyond F(n), monotonic, capped
at F(4.618); opposite completed setup closes the position next bar (no
same-bar reverse); no TP.

## Resolved differences (codex wins throughout)

1. **Same-bar extreme validation at the cross.** Codex rules 3-4: arm
   only if the cross bar shows K at the SAME-side extreme (bull cross
   → K ≥ 80) — the source presents this as the defining pattern
   ("stochastic WILL be overbought...this is the pattern"). Claude
   omitted it → **codex adopted**.
2. **Hook trigger.** Claude: K crosses the 20 level. Codex rule 8:
   after OppositeExtremeSeen, a K/D line cross with min(K,D) ≤ 20
   ("crosses over in the other direction" = line cross at the
   boundary, STR137-I3) → **codex adopted**.
3. **Impulse anchors.** Claude: 50-bar lookback param (arbitrary).
   Codex STR137-I5/I6: ImpulseStart = extreme of the entire preceding
   opposite-EMA regime (parameter-free, no look-ahead); ImpulseEnd =
   directional extreme cross→hook, frozen at the hook close →
   **codex adopted**.
4. **Trail execution.** Claude: close-based exit checks. Codex
   STR137-D2: real server-side stops ratcheted after qualifying
   closes (intrabar touch may exit early — conservative, visible
   deviation) → **codex adopted**.
5. **Cohort.** Codex defers to the card (STR137-C1). RESOLUTION:
   EURUSD.DWX + USDJPY.DWX (the author's worked example is USDJPY;
   test-design pair; flagged).

## Outcome

Final spec = codex 02 with the 2-symbol cohort declared. No
escalation.
