# STR-104 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

M5 closed-bar campaign state machine; MACD(6,17,1) zero-line ≡
EMA(6)/EMA(17) cross (thread post #2 proof; implement via pooled EMA
readers); BB(10, shift 1, dev 0.66, close); campaign start/abort on
zero cross; wick-above-without-close replaces the reference extreme;
buy/sell stop 1 pip beyond; pending persists until the opposite cross
(no bar expiry); one pending/position per magic; Method 1 baseline
(SL 1 pip beyond the breakout signal candle, TP 1R), Method 2 = labeled
variant (outer-band SL, 2R), Method 3 excluded (discretionary); no
spread/session/trend filters (unsourced).

## Resolved differences

1. **Pullback definition.** Claude: close re-enters the band zone
   (vague). Codex I-03: extension phase requires ≥1 closed bar OUTSIDE
   the near band after the cross; pullback = subsequent wick contact
   with that band (Low[1] ≤ upper band for longs). "Pull back INTO the
   bands" presupposes being outside → **codex adopted** (flagged
   finite-state reading).
2. **Breakout stop anchor.** The source's step 4 is near-tautological
   (close above the high, then stop above "the high"). Codex I-04:
   anchor the stop 1 pip beyond the CONFIRMING breakout candle's
   extreme — always ahead of market, matches Method 1's "breakout
   signal candle" language. Claude flagged the same tension without
   resolving it → **codex adopted** (material point, flagged).
3. **Filled-position exits.** Codex rule 18: a later zero cross does
   NOT close a filled position (the source assigns the cross only to
   unfilled-order cancellation); exit purely by the fixed R package →
   **codex adopted** (Claude's spec was silent).
4. **Campaign consumption.** One fill per campaign (codex I-06,
   consistent with one-position house rule) → adopted.
5. **Band-shift causality.** Codex I-02: BB plot-shift 1 means the
   value aligned to bar 1 was computed one bar earlier; implementation
   must verify buffer alignment (startup self-test) → adopted.
6. **Cohort.** Claude: EURUSD only. Codex: majors separately. Final:
   **EURUSD.DWX, GBPUSD.DWX** (M5 compute bounded; flagged).

## Outcome

Final spec = codex 02 with the 2-symbol cohort. Expected weak edge
(thread's own skeptics; M5 + 1:1 RR cost sensitivity) — falsification
candidate, Q02 gross decides. No escalation.
