# H-MR Prescreen NEAR_DUPLICATE Adjudication (vs QM5_10140)

**Date:** 2026-09-16 · **Author:** Kimi interim · **Verdict:** FALSE POSITIVE (mechanism-vocabulary overlap, structurally disjoint strategies)

## Claim
`card_intake_prescreen.py` scores QM5_41476 (cash-open-mean-reversion-h1) as `NEAR_DUPLICATE:QM5_10140_tv-london-session-break.md:score=1.0000`.

## Why the score is 1.0000
The scorer's `mechanism_overlap = shared_terms / min(len(mechanism))` reaches 1.0 when one card's mechanism-term set is a subset of the other's. Both cards legitimately share the session/breakout vocabulary ("opening range" — explicitly NON-distinctive per `_DISTINCTIVE_MECHANISMS` exclusion list line 138-142 — plus session/EMA/ATR terms). 10140's card predates this card by months and its term set is a subset of H-MR's richer vocabulary. Vocabulary overlap ≠ mechanism identity.

## Structural comparison (deterministic, from SPEC/cards)

| Dimension | QM5_10140 tv-london-session-break | QM5_41476 H-MR |
|---|---|---|
| Asset class | FX majors (London session) | Index CFDs (NDX/GDAXI/SP500) |
| Timeframe | M5 execution | H1 signal |
| Reference range | 03:00–09:00 NY London range | First N H1 bars of cash session |
| Entry conditioning | **Confirmed breakout** — first M5 close OUTSIDE range, trade WITH the break | **Failed breakout** — single H1 pierce of range extreme that CLOSES BACK INSIDE, trade AGAINST the break |
| Direction | Continuation | Mean reversion |
| Stop | Beyond breakout candle, max(0.25×ATR(M5), 5 ticks) | Beyond failed extreme + 1.0×ATR(H1) |
| Take profit | Fixed 2R | Opening-range midpoint (min-R floor) |
| Exit discipline | Window + grace period | Time stop + mandatory session-flat 20 UTC + Friday cutoff |

## Conclusion
Disjoint entry conditioning on disjoint outcome classes of an opening auction (continuation vs failure). Same-symbol-same-day opposite fills are bounded by one-entry-per-day and session-flat guards. **Prescreen NEAR_DUPLICATE is adjudicated FALSE; the authoritative duplicate authority remains the lineage map + critic review.** The differentiation paragraph added to the card body documents this permanently.

## Action
None required beyond this record. If Fable wants the scorer demoting vocabulary-subset overlaps to warnings (reason→warning) when a `Differentiation from` section is present, that is a small prescreen change — stage separately, do not tune scores ad hoc.
