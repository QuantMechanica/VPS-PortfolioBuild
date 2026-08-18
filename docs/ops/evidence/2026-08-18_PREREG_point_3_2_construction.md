---
status: PRE-REGISTERED — written before the first construction run
---

# Pre-registration — 3.2 construction: greedy forward selection with an out-of-sample holdout inside the loop

Written before any construction run exists, and before the candidate pool is frozen. Nothing here
has been executed.

3.2 is the bottleneck of both books (v6 §0). The inventory
(`2026-08-18_point_3_2_inventory_before_building.md`) established that the weighting, scoring and
out-of-sample machinery already exist and are validated; what is missing is a **selection loop**.
This states what that loop will do, what it should produce, and what would show it to be wrong.

## Inputs, and the gate on starting at all

- pool from 2.2, **frozen after (b) completes** — not the current pool. The C3 flip
  QM5_10916/SP500 (FAIL_SOFT → FAIL_HARD) showed that a recompile can move a pair between
  *categories*, not merely between numbers, so pool membership is itself vintage-dependent.
- daily series from 2.3, cost snapshot from 3.1
- **Precondition:** the construction does not run against a pool that is still being regenerated.

## Settled by inventory, not by proposal

**Objective, DZ book: `eff = ann/VaR95`.** Not a choice — the living 24 sleeves are already measured
on this scale (9.28 in-sample, 15.345 / 5.471 out-of-sample), and `dxz_weight_oos_validation.py`
derives why it is the right one: the DarwinIA-normalised return equals `6.5 * (ann/VaR95)` in the
filled regime. Any other objective makes 3.8's comparison impossible.

**Objective, FTMO book: `fund_score` as the per-step proxy**, validated against the real target in
3.5. `FUND_SCORE >= 1.0 ⟺ med60 >= wdd_p90` is already a pass-probability proxy in the right units.

**Split: 60/40 with the reverse fold**, reusing the existing implementation, so 3.8 stays comparable
by construction rather than by convention.

**Algorithm: greedy forward from the empty book, with random restarts.** The capped projected
hill-climb with restarts already exists and is constraint-correct (`0 <= w_i <= 1.0`, `sum = 9.75`).

## The loop

Start empty. At each step, for every remaining candidate, compute the objective of
`current ∪ {candidate}` **on the held-out fold**, weighted by capped inverse-vol recomputed over the
union. Take the best. Record the marginal contribution of that step. Continue to N = pool size —
**no early stop**.

**The marginal contribution is measured out-of-sample.** Selecting on the fold that also scores would
pick the sleeves that best explain the selection window, and every individual member would look
sound. This is the single most important property of the design.

## Outputs

Per book: roster, weights, admission order with the marginal contribution of each step, the objective
curve over book size **in both folds**, runtime and cost of the run, and the tail-coupling proxy
between grid sleeves (carried, per E4, **not** as a hard limit).

## Predictions, each with a falsifier

**P1 — the in-sample curve rises monotonically, the out-of-sample curve peaks and declines.**
*Falsifier:* the OOS curve also rises monotonically to N. That would mean the holdout is not binding
— either the split leaks, or the pool is too small for overfitting to appear — and the "so few as
necessary" question would have no answer from this run.

**P2 — restarts agree on the early picks.** Independent restarts should select the same first
~5 sleeves, up to ties. *Falsifier:* restarts disagree on the first five. That indicates a flat or
noisy objective surface on which greedy is the wrong algorithm, and the result would be an artifact
of the seed rather than of the data.

**P3 — the constructed DZ book reaches an OOS `eff` comparable to the living 24 (15.345 / 5.471).**
*Falsifier:* it does not, at any book size. Per v6 §3 that is a **permissible end result** — v1
stands — and it must be reported as an answer, not retried until it wins.

**P4 — a construction run is cheap enough to repeat per new candidate (E1c).** *Falsifier:* runtime
makes per-candidate reconstruction impractical. Then E1's "recompute the whole book" needs a cheaper
formulation, and that is a finding about the decision, not about the code.

## Pre-registered interpretation

The curve is the deliverable, not a single roster. The point where the **out-of-sample** marginal
contribution first turns ≤ 0 is the natural candidate for "so few as necessary", and it will be
reported as such rather than chosen by convention.

## What would invalidate the run

- the pool changing mid-run (hence the freeze precondition)
- the cost snapshot changing mid-run — the same reason 3.1 step 2 is deferred while (b) is in flight
- any objective computed on the fold used for selection

## Not claimed

No construction has been run. No roster exists. The living 24-sleeve book is untouched and stays
live until a fresh construction beats it out-of-sample.

## Evidence

- inventory: `docs/ops/evidence/2026-08-18_point_3_2_inventory_before_building.md`
- `tools/strategy_farm/portfolio/dxz_weight_oos_validation.py` — `eff`, the 60/40 + reverse fold, the
  restart hill-climb, the book's constraints
- `tools/strategy_farm/portfolio/marginal_contribution_eval.py` — capped inverse-vol reproduction
  (err 0.0000), composite deltas, regime-split correlation
