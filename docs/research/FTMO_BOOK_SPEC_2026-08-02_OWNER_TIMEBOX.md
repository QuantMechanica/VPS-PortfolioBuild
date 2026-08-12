# FTMO book spec — OWNER time-box directive 2026-08-02

**Authority:** OWNER, in-session 2026-08-02 (verbatim: „für Phase 1: 60 Tage
Zeit, für Phase 2: 30 Tage Zeit! Das sind die neuen Vorgaben! Wir wollen ein
Buch, das Phase 1 zu 80% besteht!"). Supersedes any unlimited-time assumption
in earlier FTMO planning; the speed doctrine (2026-07-26) and the
P(pass) ≥ 0.80 bar remain in force and are now bound to finite horizons.

## Binding parameters

| Parameter | Value | Note |
|---|---|---|
| Phase 1 horizon | **60 calendar days** | OWNER directive |
| Phase 1 profit target | +10 % | FTMO standard, unchanged campaign assumption |
| Phase 2 horizon | **30 calendar days** | OWNER directive |
| Phase 2 profit target | +5 % | FTMO standard |
| Daily loss limit | 5 % | unchanged |
| Max loss limit | 10 % | unchanged |
| **Design bar** | **P(Phase-1 pass) ≥ 0.80** | the book-admission criterion |
| Phase 2 estimate | reported alongside | informational; no separate bar set by OWNER |

Conventions to pin in the evaluator (fail-closed if violated): calendar-day
windows on broker time (NY-close GMT+2/+3), window start = every eligible
trading day (rolling starts) with overlap-aware uncertainty (the Book3 lesson:
overlapping starts inflate headline rates — report effective sample size and a
bootstrap lower bound, never the raw rate alone), costs from the venue cost
model with FTMO terms (no DXZ spread inheritance), and the two-phase gauntlet
evaluated sequentially (Phase-2 windows start only from Phase-1-passing paths).

## OWNER evidence-class ruling (2026-08-02, second directive)

Verified blocker: FTMO serves real ticks only for ~the last week (zero `.tkc`
caches in the installation; per-year `.hcc` M1 history only). Venue-native
multi-year Model-4 streams are therefore unobtainable, which would have left
the 0.80 bar permanently unadjudicable.

OWNER ruling, verbatim: „die Darwinexzero Backtests sind 'good enough'!" The
book decision may therefore rest on **Darwinex-executed** streams. This is a
deliberate, recorded relaxation of the venue-native requirement — not a silent
weakening. It binds the following honest implementation:

1. **Evidence class is explicit.** The admissible class becomes
   `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1`. Every artifact, result and report
   states it. Nothing produced this way may ever be described as FTMO venue
   execution. `REFUSED_DXZ_SPREAD_INHERITANCE` remains the default for any
   stream that does not carry this explicit, OWNER-authorized label.
2. **Exactly substitutable costs are substituted, not approximated.** FTMO
   commission and swap are computable per trade from the pinned FTMO snapshot
   (`7309310a…`) and the full-lifecycle trade record; the Darwinex commission
   and swap are removed and the FTMO schedule applied. A missing FTMO term
   still excludes the instrument.
3. **The spread gap is measured, and charged against us.** The residual is the
   realized Darwinex spread baked into fills. Calibrate the FTMO−DXZ spread
   delta empirically per symbol from the FTMO M1 spread series (that is the
   legitimate use of the FTMO demo: cost calibration, not execution), then
   charge a **conservative upper-percentile** delta per trade side. Where the
   delta cannot be calibrated for a symbol, exclude it.
4. **Report a sensitivity band, decide on the pessimistic end.** The decision
   number stays the moving-block bootstrap lower bound, evaluated at the
   conservative end of the spread-penalty band. If the bar is met only at the
   optimistic end, the bar is NOT met.

## Consequences

- FUND_SCORE's med60 anchor aligns with the Phase-1 horizon; sleeve ranking by
  FUND_SCORE stays the breeding yardstick.
- Low-frequency sleeves lose value under a 60-day clock: expected trades per
  window enters the pass probability directly. The Q02 5-trades/yr economics
  floor is unaffected (separate concern).
- The current inventory must be re-scored against the finite-horizon gauntlet;
  the gap to a P1-80 % book (sleeve count, density, correlation budget per
  DL-083) is the steering number for the sourcing/breeding lanes.

## Execution

Codex (Sol max) implements the two-phase finite-horizon P(pass) simulator on
the bounded-evaluation infrastructure (selection-sealed, DB-input refusal,
cost-model binding — the `book3_bound_eval.py` patterns) and re-scores the
current sleeve inventory; Claude reviews. Router ticket references this spec.
