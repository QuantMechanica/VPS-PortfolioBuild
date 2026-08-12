# CODEX BRIEF 2026-08-02 — FTMO two-phase finite-horizon P(pass) evaluator

**Author:** Claude. **Implementer:** Codex (Sol, effort max) via router lane.
**Reviewer:** Claude (close-review). **Authority:** OWNER directive 2026-08-02,
binding spec `docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md` — read
it first; its parameters are hard-bounded (Phase 1 +10 % in 60 calendar days,
Phase 2 +5 % in 30 calendar days, design bar P(Phase-1) ≥ 0.80).

**Hard constraints:** factory keeps running (no OFF/ON, no terminal starts, no
T_Live contact); read-only against farm DB and reports; no pipeline verdicts;
explicit-pathspec commits on `agents/board-advisor`. Honest-statistics rules
from the Book3 refutation are binding: never report a raw overlapping-window
rate without effective sample size and a moving-block bootstrap lower bound;
refuse silently-degraded inputs fail-closed.

## Build

`tools/strategy_farm/portfolio/ftmo_timebox_eval.py`, following the
`book3_bound_eval.py` architecture (prepare-config → evaluate, expected-config
SHA check before stream open, DB-input refusal, constant result labels):

1. **Inputs:** a book candidate = list of sleeve identities with weights;
   per-sleeve daily net equity streams from the existing bounded stream
   machinery; FTMO cost terms from the venue cost model snapshot (the spec
   forbids DXZ spread inheritance — use the FTMO terms path; if FTMO swap terms
   are absent for an instrument, REFUSE that sleeve with an explicit label, do
   not approximate silently).
2. **Gauntlet simulation:** rolling calendar-day window starts over the full
   shared-equity trace; Phase 1 = does the compound path reach +10 % within 60
   calendar days before breaching 5 % daily / 10 % max loss; Phase 2 chained
   from each Phase-1 pass point (+5 % in 30 days, same loss limits).
   Report: raw P1 rate, effective sample size (HAC-style), moving-block
   bootstrap CI (report the LOWER bound as the decision number), P2 rate given
   P1, joint rate, median days-to-target, breach taxonomy (daily vs max vs
   timeout).
3. **Inventory re-score:** run the evaluator over the current challenge-ready /
   Q08-PASS sleeve inventory in sensible book compositions (at minimum: the
   FUND_SCORE-top-N compositions for N in a small grid, respecting the DL-083
   correlation budget 0.15/0.40). Deliver the gap statement: best achievable
   bootstrap-LB P1 today vs the 0.80 bar, and which dimension is binding
   (density, expectancy, correlation, DD headroom).
4. **Tests:** synthetic-stream fixtures where the true pass probability is
   analytically known (deterministic drift + crafted breach paths) proving the
   window logic, chaining, both loss limits, the timeout taxonomy, and the
   refusal paths.

## Deliverables

Code + tests committed; `docs/research/FTMO_TIMEBOX_INVENTORY_2026-08-02.md`
with the re-score table, the gap statement, and the exact configs/SHAs to
reproduce; router task to REVIEW with that artifact path. No book is declared
"ready" by this ticket — that call is Claude-review + OWNER.
