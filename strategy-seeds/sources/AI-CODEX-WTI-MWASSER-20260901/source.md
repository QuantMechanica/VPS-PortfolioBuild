---
source_id: AI-CODEX-WTI-MWASSER-20260901
source_type: ai_originated_governed_synthesis
title: WTI monthly exact-permutation Wasserstein-1 shift continuation
author: OpenAI Codex
supporting_authors: Aaditya Ramdas; Nicolas Garcia; Marco Cuturi; SciPy community; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_wasserstein_shift_trend_source_approval.md
created: 2026-09-01
created_by: Codex
last_reviewed: 2026-09-01
cards_extracted: []
---

# WTI Monthly Exact-Permutation Wasserstein-1 Shift Continuation

## Canonical origin and prompt trail

This is the single R1 lineage for one bounded AI-originated strategy. The
current explicit OWNER mission asks for one genuinely new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, names direct WTI trend or seasonality as an
eligible route, requires reputable-source criteria and a fixed-risk baseline,
and authorizes a branch-only build plus one paced Q02 enqueue.

Codex selected and locked the Wasserstein-1 mechanic below before any market
test. It is an untested QM synthesis. Neither the statistical authors, SciPy,
nor the WTI paper reports this trading rule or an efficacy result for it.

## Supporting evidence and access boundary

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It supports only WTI membership, monthly
decisions, and own-return continuation. It does not test this signal.

Ramdas, Garcia, and Cuturi (2015), arXiv `1509.02237`, was read for its
nonparametric two-sample setup, Wasserstein definition, one-dimensional
quantile representation, method-family relationships, and proof boundary.
The PDF retrieval receipt is
`retrieval_route_ramdas_wasserstein_20260901.json`.

SciPy 1.13.1 official documentation and pinned source at commit
`44e4ebaac992fde33f04638b99629d23973cb9b2` were read for the public
Wasserstein-1 definition and equal-weight empirical implementation. The
source blob and SHA-256 receipt are in
`retrieval_route_scipy_wasserstein_20260901.json`.

The exact six-by-six split, full label enumeration, inclusive three-fifths
tail, median direction, WTI CFD translation, stop, risk, and lifecycle are
disclosed QM choices.

## Locked hypothesis and rules

Physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can move the quantiles of WTI monthly-return distributions.
When the newest six completed returns have a sufficiently large
Wasserstein-1 displacement from the prior six, continue the direction of the
block-median shift for one monthly package.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct thirteen consecutive completed `XTIUSD.DWX` broker-month end
   closes and form twelve adjacent finite log returns.
2. Fix the oldest six returns as `old` and newest six as `recent`.
3. Sort both six-value blocks ascending. For equal uniform empirical samples,
   compute `W1 = sum(abs(old_sorted[j]-recent_sorted[j]), j=0..5)/6`.
4. Enumerate all `C(12,6)=924` fixed-size pseudo-recent label assignments.
   Recompute the same sorted-pair `W1_perm` and count the inclusive upper tail
   `W1_perm + eps >= W1_observed`, where
   `eps = 1e-12 * max(1, abs(W1_observed))`.
5. Qualify only when `5*tail_count <= 3*924`, equivalently
   `tail_count <= 554`. This is a locked 60% activity boundary, not a
   significance level or imported critical value.
6. Buy when `median6(recent)-median6(old)>1e-12`; sell when it is below
   `-1e-12`; otherwise consume the month flat. Distance magnitude never
   scales risk.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
8. Exit on the first tick of the next broker month or after forty elapsed
   calendar days as stale repair. No same-month retry is allowed.

The month key is persisted before history, signal, quote, ATR, size, or order
gates. Current-month price is never part of the signal.

## Activity prior fixed before build

For pooled values `0..11`, all 924 six-label assignments were exhaustively
enumerated. Exactly 540 assignments have inclusive Wasserstein tail count at
most 554, implying `12*540/924 = 7.012987...` decisions per year before market
and execution gates. Squared and exponential pooled fixtures imply 6.91 and
7.12 decisions per year respectively. This is a combinatorial activity prior,
not a performance test. Q02 must still prove at least five completed positions
in every full scored year or retire the EA.

## Non-duplicate review

The canonical preallocation receipt
`artifacts/qm5_wti_mwasser_shift_tr_preallocation_dedup_20260901.json` found no
exact slug or strategy identity across 4,758 registry rows, 1,395 cards, and
45 Strategy Wiki nodes. It returned the expected fuzzy family neighbors:

- `QM5_41258` uses cross- and within-block pairwise distances in the energy
  statistic. This candidate uses only monotone equal-quantile transport pairs.
- `QM5_41255` uses pooled ranks and an integrated squared membership path,
  discarding return spacing. This candidate keeps return magnitudes.
- `QM5_41250` compares within-block median absolute deviations only.

Fixed nonlinear fixtures prove the statistics are not aliases. With squared
pooled values and pseudo-recent ranks `{0,1,2,5,8,10}`, energy qualifies at
tail 508 while Wasserstein stays flat at 572. With exponentially spaced
values `exp(rank/3)` and ranks `{0,2,3,5,7,10}`, Wasserstein qualifies at 540
while energy stays flat at 556. The exponential fixture with ranks
`{0,1,4,6,8,9}` qualifies Wasserstein at 496 while integrated ECDF stays flat
at 700; ranks `{0,1,2,4,8,10}` give the reverse (Wasserstein 588, integrated
ECDF 230).

Manual verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_FIXED_SIX_BY_SIX_WASSERSTEIN_ONE_SORTED_QUANTILE_DISTANCE_EXACT_PERMUTATION_SHIFT_CONTINUATION`.

## R1-R4 assessment

- R1: `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`. Complete governed
  peer-reviewed WTI evidence, a public statistical paper, pinned official
  SciPy documentation/source, hashes, and an explicit no-performance boundary.
- R2: `PASS`. Clock, endpoints, returns, sorted-pair formula, complete
  enumeration, tolerance, boundary, side, attempt, risk, stop, spread, and
  lifecycle are deterministic.
- R3: `PASS_WITH_CONTINUOUS_CFD_RISK`. Registered `XTIUSD.DWX` D1 history and
  native MT5 state supply every runtime input; roll, gap, financing, broker
  month labels, and futures-to-CFD basis remain empirical risks.
- R4: `PASS`. Sorting, subtraction, absolute values, sums, logarithms, ATR risk,
  quote/position/deal state, and persistence only; no ML, prohibited indicator,
  optimizer output, external runtime data, grid, or martingale.

## Claim boundary

The supporting sources establish a reputable WTI monthly continuation lineage
and a reputable distribution-distance definition. They do not establish this
six-by-six rule, the 60% activity boundary, CFD equivalence, profitability,
neutrality, correlation, or robustness. Q02 and later deterministic gates own
those findings; Q09 alone may measure portfolio overlap.
