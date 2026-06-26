# PR: Q09 admission `diversifies` test on risk-parity weighting (review branch)

Branch: `portfolio/diversifies-risk-parity` (off `main` @ dba239060). **Review-gated** — do not
merge without OWNER/Codex review. No push performed by the author.

## Problem

The Q09 admission gate (`portfolio_admission.evaluate_candidate`) decides `diversifies` by
comparing the book with/without the candidate using **equal-weight** `portfolio_metrics`. But the
production book is assembled with **risk-parity (inverse-vol)** weights (`book_monitor`,
`build_real_portfolio`). Gating diversification on a weighting the book never uses rejects real
diversifiers: a dense, high-trade-count sleeve dominates the daily variance under equal weight, so
it looks non-diversifying even when, properly weighted, it *reduces* the book's drawdown.

Concretely (post-NDX-recovery, 2026-06-26): `10692:NDX` and `10440:NDX` clear the trade floor and
the correlation cap (monthly `corr_basis`, −0.02 / +0.06) but were rejected `no_diversification`,
because under equal weight adding the dense 443-/441-trade NDX sleeve raised the equal-weight DD.
This was the binding blocker keeping the certified book at 3 sleeves.

## Change

- `portfolio_kpi.inverse_vol_weights(keys, common_dir)` — risk-parity weights over daily PnL,
  numpy-optional (SYSTEM AppData Python has no numpy), equal-weight fallback when no sleeve has
  positive vol.
- `portfolio_admission.evaluate_candidate` — the `diversifies` with/without comparison now uses
  `inverse_vol_weights` instead of `equal_weights`, matching how the book is actually built.

No change to the correlation gate, the trade floor, or the monthly-corr fallback.

## Validation

Tests (`tools/strategy_farm/tests/test_portfolio_*`): **22 pass**, including:
- updated `test_candidate_without_portfolio_improvement_is_rejected` — fixture changed to an
  uncorrelated **net-losing** sleeve (the only honest no-diversification case once weighting is
  risk-parity; a net-negative *anti-correlated* sleeve legitimately diversifies by smoothing).
- new `test_risk_parity_admits_dense_diversifier_that_equal_weight_rejects` — asserts the exact
  behaviour change: a high-vol uncorrelated sleeve that equal-weight rejects is admitted under
  risk-parity.

Real data (live book `10513:XAU, 10940:XAU, 11132:SP500`, recovered NDX streams):

| candidate | corr_basis | max_corr | maxdd without→with | diversifies | verdict |
|---|---|---|---|---|---|
| 10692:NDX | monthly | −0.02 | 19.91% → **16.92%** | True | **admitted** |
| 10440:NDX | monthly | +0.059 | 19.91% → **16.58%** | True | **admitted** |

→ certified book **3 → 5 sleeves** (adds NDX as a 4th instrument; both *reduce* book DD).

## Scope / risk

- This changes Q09 admit decisions fleet-wide, not just NDX — hence review-gated. It is strictly
  more permissive only where a candidate reduces the **risk-parity** book DD or raises its Sharpe.
- `diversifies` remains an OR of (Sharpe-up, DD-down). NDX admits via DD reduction while its Sharpe
  dips — correct for a DD-targeted book (FTMO 10%), but if OWNER wants a risk-adjusted criterion
  (e.g. require Sharpe-or-DD beyond a margin) that is a follow-up.
- After merge: re-run Q09 for the NDX candidates (and the watchlist) so the pump promotes the new
  PASS_PORTFOLIO; clear the `10692:NDX` `EVIDENCE_STALE` row so it can be re-admitted.

Files: `portfolio_kpi.py`, `portfolio_admission.py`, `test_portfolio_admission.py`, this doc.
