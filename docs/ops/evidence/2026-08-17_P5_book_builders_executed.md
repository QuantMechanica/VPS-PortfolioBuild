# P5 — Both book builders run, both books fail their own bars, and the two gates disagree

## They are finished production code, not skeletons

Executed both against today's inputs, dry-run, output directed to a scratch path so nothing
in the pipeline was touched.

**`build_book_dxz.py`** → `status: NOT_WORSE_BAR_NOT_MET`, 24 sleeves, manifest + evidence
written, `exit=0`. It emits a roster SHA-256, a hash-bound sleeve list, the common history
window (`2019-07-23` → `2024-12-13`, 1349 days), the weighting (capped inverse-vol, cap 1.0,
total risk 9.75%) and a three-check incumbent gate.

**`build_book_ftmo.py`** → `status: BAR_NOT_MET`, **0 sleeves**, `bootstrap_gap: 0.8`,
manifest + evidence written, `exit=0`. It emits a candidate roster hash, a selected roster hash
(the SHA of an empty list, consistent with 0 sleeves) and a five-check fail-closed bar.

Neither is abandoned, neither needed repair to run, and both refuse to recommend application.
`APPLY_RECOMMENDED` / a paid challenge are explicitly OWNER ceremonies outside the tools.

## Both books fail their own bars today — in named, checkable terms

**DXZ incumbent gate:**

| Check | Result |
|---|---|
| `return_to_maxdd_not_worse` | **FAIL** |
| `worst_day_not_worse` | PASS |
| `maxdd_not_worse` | **FAIL** |

**FTMO fail-closed bar:**

| Check | Result |
|---|---|
| `fund_score_each_at_least_1` | **FAIL** |
| `one_ea_per_symbol` | PASS |
| `density` | **FAIL** |
| `cost_and_swap_snapshot_coverage` | PASS |
| `bootstrap_lower_bound_at_least_0p80` | **FAIL** |

So the answer to "what would a book build deliver today" is: **nothing deployable — and both
tools say so precisely.** The missing piece is not tooling. It is candidates that clear the bar,
which converges with today's admission finding that the pipeline is producing sleeves that
dilute the book.

## The number that qualifies my own P1 reversal

DXZ manifest, at the deployed total risk of 9.75%:

| | incumbent | proposal |
|---|---:|---:|
| annual_return_pct | 10.131 | **10.216** |
| sharpe | 2.536 | **2.568** |
| max_drawdown_pct | **2.238** | 2.270 |
| return_to_maxdd | **4.526** | 4.501 |
| worst_day_pct | −0.857 | **−0.828** |

**Book-level MaxDD is 2.24%, not sub-1%.** Earlier today I concluded from the admission evidence
that book drawdown is sub-1% and therefore that MaxDD deltas are noise. That conclusion holds
*for the admission gate's own basis* — there the figures really are ~0.3% and deltas of 0.02pp
really are noise. **It does not generalise to the book layer**, which measures at a different
risk/capital basis and where DD is an order of magnitude larger. I am recording that limit
explicitly rather than letting the earlier statement stand unqualified.

## And the two gates pull in opposite directions

Read the DXZ result carefully: the proposal **improves Sharpe (2.536 → 2.568) and return (10.13
→ 10.22)** and is rejected because MaxDD worsens by **0.03 percentage points**.

Now compare the candidate admission gate, `portfolio_admission.diversifies` (DL-079): a
candidate is admitted iff it improves Sharpe, **or** improves MaxDD *without degrading Sharpe* —
explicitly because "a marginal MaxDD improvement is not worth a Sharpe cost".

| Layer | Policy |
|---|---|
| candidate admission (Q09_PORTFOLIO, DL-079) | **Sharpe-protective** — refuse DD gains that cost Sharpe |
| book proposal (Q11_DXZ, DL-084) | **drawdown-protective** — refuse Sharpe gains that cost DD |

These operate on different objects — one candidate's marginal contribution versus a whole-book
proposal against the incumbent — and on different bases, so this is not automatically a defect.
But the funnel currently admits sleeves on a Sharpe-first rule and then assembles books under a
DD-first rule. **A candidate can clear the gate that lets it in and block the gate that would
deploy it**, which is exactly what a 0.03pp MaxDD worsening at book level does here.

That is a question for OWNER, not something to reconcile unilaterally: **which layer owns the
risk preference?** My reading is that DL-079's rationale ("MaxDD headroom is abundant") is a
statement about the *admission* basis, while DL-084's not-worse gate is the deployment reality
at 9.75% total risk — and if so, the admission rule's DD-noise argument should be re-derived at
the deployment basis rather than the evaluation basis.

## Gaps against the real code, not against my earlier specification

1. **No selection holdout.** DXZ compares proposal against incumbent on the *same* history
   (1349 days, one window). That is a disciplined comparison but it is not an out-of-sample
   evaluation of the *selection*. FTMO's bar is a set of thresholds, also not a holdout. This is
   the first genuine gap, and it is the one PB discipline point that survives contact with the
   code: **a book that only convinces on the window it was selected on is an overfit, and every
   component looks clean while it happens.**
2. **`ftmo_rules_engine.py` is undated in the runbook.** 1,188 lines encode a rule state; which
   one, and does it match the rules in force? Not established this round.
3. **The FTMO `bootstrap_lower_bound` needs a source.** `bootstrap_gap: 0.8` against a required
   0.80 lower bound means the bootstrap input is absent, not that the book failed on merit — the
   builder's docstring says it "never harvests terminal data itself" and requires a declared
   `ae5331f67` M1 bootstrap lineage.

## What this does not mean

Nothing here says either book is close to deployable. Both fail multiple named checks. But the
failures are now *legible*: three checks for DZ, five for FTMO, each with a value behind it. That
is the difference between "the book build is missing" and "the book build says no, for these
reasons".

## Evidence

- dry-run output: `.../scratchpad/book_dryrun/{dxz,ftmo}/manifest.json` and `evidence.md`
- `tools/strategy_farm/portfolio/build_book_dxz.py`, `build_book_ftmo.py` (DL-084)
- `tools/strategy_farm/portfolio/portfolio_admission.py:392-420` (DL-079, the Sharpe-protective rule)
- related: `2026-08-17_P1_book_test_recompute_and_my_reversal.md`
