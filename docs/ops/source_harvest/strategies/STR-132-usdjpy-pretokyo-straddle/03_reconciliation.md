# STR-132 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

USDJPY.DWX; ET-civil anchors (18:00-20:00 range, 22:00 entry cutoff)
DST-aware — the source's "22:00-00:00 GMT" parenthesis is the EDT
special case, ET governs (both specs, codex FLAG-132-01); straddle
stops at exactly ±2.0 pips (JPY 3-digit pip = 10*_Point, both); SL 15
pips + captured spread; TP1 40 pips on 50% (netted partial per house
machinery, source post #75 itself calls one double-lot position
equivalent — codex FLAG-132-03); no SL move before TP1; runner TP 70;
OCO-cancel on first fill (bounded projection, both); one campaign per
ET date, no re-entry/reverse; no time exit for FILLED positions
(cutoff governs entry only, FLAG-132-06); blackout intersecting the
entry window blocks the date; hype claims excluded from spec
(FLAG-132-07).

## Resolved differences

1. **Execution TF.** Claude: M5. Codex: M15 (8 range bars; 20107
   precedent). The window extremes are TF-invariant and pendings
   trigger server-side — M15 is the leaner equivalent → **codex
   adopted**.
2. **Runner BE offset.** Source: "BreakEven or +1". Claude: +1.
   Codex FLAG-132-04: exact BE primary (+1 = labeled variant, first
   literal option) → **codex adopted**.
3. **Spread snapshot timing.** Claude: unaddressed beyond "+spread".
   Codex FLAG-132-02: capture at protected-pending placement, never
   widen later; on-fill snapshot = variant → **codex adopted**.
4. **Both-sides-or-nothing placement + OCO-race anomaly flatten**
   (codex rules 6, FLAG-132-05) → adopted.
5. **Volume splittability gate** (codex rule 12: reject the date if
   50% is not step-legal — protects the 50/50 payoff instead of
   distorting it) → adopted; stricter than the 20139 skip-partial
   fallback and appropriate here because the split IS the payoff
   structure.

## Overlap verdict

Codex's mandatory table (02 §7) vs QM5_20107 and live QM5_9936:
different clocks (2h ET vs 5h broker/GMT+3), offsets (2.0 pips vs
border), stops (fixed 15+spread vs opposite border), payoff (40/70
split+BE vs trail exits), windows — materially distinct mechanics;
retained as a distinct candidate. Claude's 01 overlap note concurs.

## Outcome

Final spec = codex 02 unchanged except confirmations above. No
escalation.
