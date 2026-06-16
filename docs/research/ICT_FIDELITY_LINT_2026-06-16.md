# ICT Fidelity Lint — killzone matrix (12535-12540) vs OWNER's course notes

**Author:** Claude · **Date:** 2026-06-16 · **Method:** lint our 6 ICT killzone-matrix
cards against the canonical rules extracted from OWNER's legally-owned course notes
(Twfx-Forex-Ict-Mmm-Notes, Trading Hub 3.0), mined in
`LIBRARY_MINING_ict-mmm-notes-2020_2026-06.md` + `LIBRARY_MINING_ict-trading-hub-notes_2026-06.md`.
Purpose: catch the "right family, wrong realization" failure mode (Fidelity Initiative).

## Verdict: our matrix is DOCTRINE-FAITHFUL on the critical dimensions ✅

The retail "wrong realization" failure modes — (a) entering on the sweep before MSS
confirmation, (b) fixed-pip take-profits — are the exact things the MMM notes contain and
that the canonical ICT 2022 model prohibits. **Our cards avoid both.** Verified per card:

| Dimension | Canonical rule | Our cards | Verdict |
|---|---|---|---|
| MSS required before entry (NON-NEGOTIABLE) | closed MSS bar confirming displacement | 12535/12536/12537/12539 all require "MSS within 8 bars of sweep" | **FAITHFUL** |
| TP model | hold to next liquidity pool, NOT fixed pips | all use TP1 = opposite liquidity pool (PDH/PDL/Asia-range), R-capped | **FAITHFUL** |
| Killzone windows | NY 07:00-10:00 ET; London 09:00-12:00 broker | cards use broker 14:00-17:00 NY / 09:00-12:00 London; DXZ broker tracks US DST (GMT+2/+3) so broker 14:00 = ET 07:00 YEAR-ROUND | **FAITHFUL** (cards correctly note "ET-stable year-round") |
| FVG entry | limit at FVG midpoint (consequent encroachment) AFTER MSS | 12535/12539 = FVG midpoint post-MSS | **FAITHFUL** |
| Entry-geometry variants | OB mean-threshold / OTE 70.5% are canonical alternatives | 12536 (OB), 12537 (OTE) = legitimate A/B/C of the one free variable | **FAITHFUL** (deliberate experiment) |
| AMD/Judas (no MSS) | reversal of the false break itself — MSS not required | 12540 trades the false-break reversal, no MSS | **CONSISTENT** (correct exception) |

## Gaps (canonical profiles NOT yet carded — not mismatches, missing coverage)
1. **London Close Reversal Profile** (15:00-17:30 broker reversal after a London sweep) —
   a distinct canonical profile we have no card for. Already proposed as QM5_12550 in the
   morning mining (`ict-london-close-reversal-m15`). → build it.
2. **Turtle Soup 2-step** (first false break of Asian range → re-close → SECOND larger
   Judas swing = the real entry). Our 12540 is single-step AMD; the 2-step is a distinct
   refinement that filters false trades by requiring two attempts. Proposed as QM5_12551
   (`ict-turtle-soup-asian-false-break-m15`). → build it.

## One caution carried into the cards (already handled)
The MMM notes are an educational compilation (Mmari 2020), NOT the canonical 2022 source;
some MMM profiles enter on the sweep bar before MSS, and use fixed 20-30 pip TPs. These are
the "wrong realization" — and our cards deliberately do NOT follow them. Any future ICT
card MUST keep MSS-before-entry and liquidity-pool TPs. This lint confirms the matrix holds
the line.

## Conclusion
No fidelity defects in 12535-12540. The matrix is the correct realization of the family
whose only in-house Q12 survivor (10692) is the same sweep+MSS mechanism. The two gaps
(12550/12551) are coverage, not correctness — build them to complete the matrix. The
binding question for the family stays empirical (does killzone-conditioning + retrace-entry
beat 10692's any-session structure-close entry), now testable once these build and run.
