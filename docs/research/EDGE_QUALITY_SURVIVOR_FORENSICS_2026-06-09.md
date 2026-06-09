# Edge-Quality Survivor Forensics — what actually survives the V5 funnel

**Author:** Claude · **Date:** 2026-06-09 · **Status:** evidence brief (input to the
Edge-Quality Initiative)

## The problem in one number

717 EAs built → **1** thin portfolio candidate (QM5_10692, held as book member #1).
The funnel's *throughput* works; its *yield* does not. The bottleneck is **edge quality**,
not testing capacity.

## Where edges die (evidence)

Distinct-EA survival from a Q02 (smoke) pass, denominator-corrected:

| | reach Q04+ (walk-forward) | reach Q07+ |
|---|---|---|
| Generic `mql5-*` indicator strategies | 9/63 = **14%** | 6% |
| Thesis-driven / Edge-Lab / other | 11/95 = **12%** | 3% |

Two findings that overturn a prior assumption:

1. **Thesis-driven does NOT beat generic** (~12–14% Q04 survival each). "More thesis cards"
   is not the lever. The failure is *fundamental*, not source-dependent.
2. **~88% die at Q04 (walk-forward out-of-sample)**, and the Q04 winners use **needle
   parameters** (median: only ~11% of the Q03 grid passes Q04). I.e. the surviving
   parameter set is a minority found by search → inherently overfit-prone → then Q08 kills
   them on PBO (probability-of-backtest-overfitting; the lone candidate sits at PBO 51%).

**Conclusion: the common cause of death is overfitting / no persistent OOS edge.**

## What the deepest survivors share (the signal)

The 3 *thesis-driven* deep survivors (Q07+) — read from their cards:

| EA | Edge | Structural cause | Free params |
|---|---|---|---|
| **QM5_10260** cieslak-fomc-cycle | Equity premium realized *only* in even FOMC-cycle weeks (Cieslak-Morse-Vuolteenaho, *J. Finance* 2019; t>4, robust across sub-samples & internationally) | Monetary-policy information diffusion | **≈ 0** (just the FOMC calendar) |
| QM5_10627 tq-spy-zscore | 20-day z-score mean-reversion, long < −1.5, exit at z>0 | Short-term overreaction reverts | 2 |
| QM5_10692 tv-ls-ms | Liquidity sweep → opposite structure break, ATR-adaptive exit | Stop-hunt microstructure | structural rules |

The generic `mql5-*` deep entries (hs-rev, ichimoku, trendmgr, ohlc-mtf) are indicator/
pattern mashups with **no economic cause and more knobs** — exactly the overfit profile.

**The pattern that survives walk-forward:**
1. a **documented structural / economic cause** (why the edge exists *and persists*);
2. **near-zero free parameters** — nothing to optimize ⇒ Q04/Q08 cannot punish overfitting
   *by construction* (the FOMC edge is just a calendar);
3. **academic / first-principles grounding**, not a flashy in-sample backtest.

## Implication for "better research"

Not *more* research, and not *thesis-vs-generic* — but a quality bar:

> **Target near-zero-parameter, structurally-caused, evidence-validated anomalies.**
> The fewer the free parameters, the higher the walk-forward survival odds — because the
> thing that kills us (parameter overfitting) has nothing to grab.

This reframes the Edge-Lab 4 directions toward **calendar/seasonal, macro-event-conditioned,
cross-sectional relative-value, simple mean-reversion, and microstructure/overnight** edges —
families where the rule is dictated by structure, not fit to history. Diversity (different
mechanism × asset × holding period, low mutual correlation, low correlation to the intraday
NDX momentum candidate) is the portfolio requirement on top.

A rigorous, adversarially-verified research sweep for such edges is in progress
(deep-research harness, 2026-06-09); the build-ready candidate cards + portfolio-fit
synthesis will follow as the second half of this initiative.

## Caveat (intellectual honesty)

N is small at the deep end (7 Q07+ survivors, 1 portfolio pass). The *failure-mode* finding
(overfitting kills, ~88% Q04 attrition) is statistically solid (N=158 at Q02-pass). The
*winning-recipe* finding (structural + few-param) is directionally strong but should be
re-tested as the survivor cohort grows. This brief is a hypothesis to act on, not a proof.
