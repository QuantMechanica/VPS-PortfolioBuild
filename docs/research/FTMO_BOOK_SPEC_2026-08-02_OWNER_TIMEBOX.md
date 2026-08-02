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
