# Point 3.2 — inventory before building: the construction machine is a selection loop around parts that already exist

v6 §3.2 names five modules to reuse and calls construction the bottleneck of both books. §5 lists
"Konstruktionsmodus" among the missing machines. This is the inventory that says which half is
missing.

## All five named modules exist

| module | size | last touched |
|---|---:|---|
| `portfolio/marginal_contribution_eval.py` | 29,140 B | 2026-07-20 |
| `portfolio/portfolio_resize.py` | 38,969 B | 2026-07-19 |
| `portfolio/book_sizing.py` | 6,833 B | 2026-06-30 |
| `portfolio/portfolio_correlation.py` | 6,334 B | 2026-06-01 |
| `portfolio/sleeve_correlation.py` | 5,504 B | 2026-07-26 |

Plus the one §3.2 and §3.8 depend on without naming it: `portfolio/dxz_weight_oos_validation.py`
(8,002 B, 2026-07-11).

## What already exists — more than the brief assumes

**The objective function is defined and implemented.** `dxz_weight_oos_validation.py` defines
`eff = ann/VaR95` — return-per-VaR efficiency — and derives why it is the right DXZ scale: the
DarwinIA-normalised return equals `6.5 * (ann/VaR95)` in the filled regime. That is the `eff` scale
§3.2 proposes for the DZ objective and §3.8 needs for the comparison against the living 24.

**The out-of-sample discipline is implemented, in exactly the shape §3.2 specifies.** The module
fits on 60% of months and scores on the held-out 40%, *and the reverse fold* — "the honest DXZ
optimum is the weighting that wins OUT-OF-SAMPLE". §3.2's requirement that the marginal contribution
be measured out-of-sample is therefore not a new capability; it is an existing one that needs to be
called from a different loop.

**An optimiser exists that fits the constraints.** Capped projected hill-climb with random restarts,
no scipy dependency, under the book's real constraints (`0 <= w_i <= 1.0`, `sum(w) = 9.75`). §3.2's
proposed "greedy with random restarts against local optima" has its numerical core here already.

**The weighting rule is verified, not merely present.** `marginal_contribution_eval.py` recomputes
capped inverse-vol over incumbent ∪ candidate and *"verified to reproduce the sealed 24-sleeve
weights exactly, err 0.0000"*. Composite ΔSharpe / ΔMaxDD / Δworst-day and regime-split correlation
(disjoint thirds + high-volatility quintile + monthly cross-check) are implemented alongside.

## What is genuinely missing — and it is one thing, not five

**Both existing tools take the roster as given and optimise weights over it.**
`marginal_contribution_eval` asks *"does this candidate help the sealed book?"*;
`dxz_weight_oos_validation` asks *"which weighting of this roster wins out-of-sample?"*. Neither
selects members.

E1 abolished the first question outright — *"Der Grenzbeitrag gegen ein Incumbent verschwindet als
Konzept"* — so `marginal_contribution_eval`'s **framing** is retired even though its **machinery**
is not. That distinction is the whole finding: the parts survive E1, the orchestration does not.

So 3.2 is not a build-from-scratch. It is a **selection loop** — greedy forward from the empty book,
scoring each step out-of-sample — wrapped around weighting, scoring and OOS machinery that already
exists and is validated.

## What this changes about the plan

- §3.2's ⬥ decision on the objective function can be taken as settled by inventory rather than by
  proposal: `eff` exists, is implemented, and is the only scale on which the living 24 (9.28
  in-sample / 15.345 / 5.471 out-of-sample) are already measured. A different objective would make
  3.8 incomparable.
- §3.2's ⬥ on the algorithm is likewise narrowed: the restart-hill-climb core is written and
  constraint-correct.
- The **holdout inside the selection loop** — §3.2's sharpest requirement — reuses the same 60/40 +
  reverse-fold split, which keeps 3.8 comparable by construction rather than by convention.
- The remaining work is the loop itself, its stopping curve (value over book size, both folds), and
  the E1c requirement that a construction run be cheap enough to repeat per new candidate.

## Not yet examined

`portfolio_resize.py` (39 KB) is the largest of the five and has not been read beyond its size; it
may already contain part of the selection logic. `book_sizing.py` likewise. Both are next, and this
inventory is provisional on them.

## Evidence

- module census under `tools/strategy_farm/portfolio/`
- `dxz_weight_oos_validation.py` docstring — `eff` definition, 60/40 + reverse fold, optimiser and
  constraints
- `marginal_contribution_eval.py` docstring — capped inverse-vol reproduction (err 0.0000), composite
  deltas, regime-split correlation, its stated reuse of the OOS discipline
