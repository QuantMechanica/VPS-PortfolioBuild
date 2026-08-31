---
source_id: AI-CODEX-WTI-MENERGY-20260901
source_type: ai_originated_governed_synthesis
title: WTI monthly exact-permutation energy-distance shift continuation
author: OpenAI Codex
supporting_authors: Gabor J. Szekely; Maria L. Rizzo; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_energy_distance_shift_trend_source_approval.md
created: 2026-09-01
created_by: Codex
last_reviewed: 2026-09-01
cards_extracted: []
---

# WTI Monthly Exact-Permutation Energy-Distance Shift Continuation

## Canonical origin and prompt trail

This is the single R1 lineage for one bounded AI-originated strategy. The
current explicit OWNER mission asks for one genuinely new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, names direct WTI trend/seasonality as an
eligible route, requires reputable-source criteria and a fixed-risk baseline,
and authorizes a branch-only build plus one paced Q02 enqueue.

Codex selected and fixed the energy-distance mechanic below before any market
test. It is an untested QM synthesis, not a strategy reported by the
statistical-method authors and not a claim that an equality-of-distributions
test has discovered WTI alpha.

## Supporting evidence and access boundary

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It supports only WTI membership, monthly
decisions, and own-return continuation. It does not test this signal.

The public CRAN `energy` 1.7-12 manual and R sources were read completely at
commit `5c2b2d553b4245ebe2a7fd933d93b8917cea799b` through the public GitHub API.
The pinned paths and SHA-256 receipts are in
`retrieval_route_cran_energy_20260901.json`. They supply the two-sample
distance formula and resampling context only. The Wiley review by Rizzo and
Szekely (2016), DOI `10.1002/wics.1375`, is bibliographic context only: the
deterministic generic reader returned `DEFERRED:SOURCE_POLICY`, preserved in
`retrieval_route_wiley_20260901.json`. No inaccessible content is imported.

The exact six-by-six split, complete label enumeration, inclusive three-fifths
tail, median direction, WTI CFD translation, stop, risk, and lifecycle are
disclosed QM choices.

## Locked hypothesis and rules

Physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can change the location, scale, or shape of WTI monthly-return
distributions. Continue a sufficiently broad newest-six versus oldest-six
distribution displacement in the direction of the block-median shift for one
month.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct thirteen consecutive completed `XTIUSD.DWX` broker-month end
   closes and form twelve adjacent finite log returns.
2. Fix the oldest six returns as `old` and newest six as `recent`.
3. For samples `A` and `B`, each of size six, compute ordered-pair averages
   `M_AB`, `M_AA`, and `M_BB` of absolute return distance, including zero
   self-distances in the within-sample averages. Compute
   `E = 3 * (2*M_AB - M_AA - M_BB)`.
4. Enumerate all `C(12,6)=924` fixed-size pseudo-recent label assignments.
   Recompute `E_perm` from the same twelve return magnitudes and count the
   inclusive upper tail `E_perm + eps >= E_observed`, where
   `eps = 1e-12 * max(1, abs(E_observed))`.
5. Qualify only when `5*tail_count <= 3*924`, equivalently
   `tail_count<=554`. This is a 60% activity cap, not a significance level.
6. Buy when `median6(recent)-median6(old)>1e-12`; sell when it is below
   `-1e-12`; otherwise consume flat. Statistic magnitude never scales risk.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap.
8. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off.

A market-free equally spaced twelve-value fixture admits 540 of 924 label
states at the locked tail cap, or 7.013 decisions per twelve evaluations. That
is a deterministic activity reference, not a market probability.

## Non-duplicate boundary

The corrected-root checker scanned 4,757 registry identities, 1,394 card files,
and 45 Strategy Wiki nodes. It found no exact identity and three expected fuzzy
method neighbors. Receipt:
`artifacts/qm5_wti_menergy_shift_tr_preallocation_dedup_20260901.json`,
SHA-256 `23556367C32FB5934B0EAD67BD10C5D97FF35A107FEB85D52083FC20AB499697`.

The load-bearing distinctions are:

- `QM5_41255` is rank-only and integrates squared ECDF membership imbalance;
  this rule uses actual pairwise return distances and is not invariant under a
  nonlinear monotone transformation.
- `QM5_41250` compares within-block median absolute deviations only; this rule
  combines all cross-block and both within-block absolute distances.
- `QM5_41257` retains only the recent count above the pooled grand median;
  this rule uses every return magnitude and every pairwise distance.
- Welch, Mann-Whitney, KS, Brunner-Munzel, CSS, CUSUM, and Chow neighbors do
  not implement the same energy statistic plus exact 924-label tail.

Fixed separating fixtures are part of the build reference tests. With pooled
values `0..11` and pseudo-recent ranks `{0,1,3,5,8,10}`, energy qualifies at
tail 540 while the integrated-ECDF neighbor is outside its locked tail. With
squared pooled values and ranks `{0,1,2,6,8,10}`, the integrated-ECDF neighbor
qualifies while energy is tail 636 and stays flat.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_ENERGY_DISTANCE_EXACT_924_LABEL_PERMUTATION_THREE_FIFTHS_TAIL_MEDIAN_DIRECTION_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_PINNED_PRIMARY_SOFTWARE`: exactly one durable
  AI source ID and prompt/output trail; complete-read peer-reviewed WTI
  evidence; complete pinned CRAN method manual/source; explicit Wiley policy
  boundary.
- R2 `PASS`: clock, endpoints, returns, fixed blocks, distance arithmetic,
  tolerance, complete enumeration, boundary, side, attempt, fixed risk, stop,
  spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1
  history and MT5 state supply all runtime inputs; roll, financing, basis,
  gaps, and broker-month labels remain risks.
- R4 `PASS`: completed prices, logarithms, absolute distances, fixed loops,
  comparisons, medians, ATR risk, quotes, positions, deals, and persistent
  state only; no trained output, prohibited signal indicator, random runtime
  resampling, external feed, grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. Q02 retires zero trades,
any full scored post-warm-up year below five completed positions, nonpositive
governed economics, future leakage, or a deterministic-fixture failure. Q09
alone owns realized overlap. Failure may not be rescued by changing the
sample, statistic, tolerance, tail cap, direction, stop, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if the whole-host CPU ceiling permits. It authorizes
no manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or live manifest, portfolio-gate mutation, correlation
waiver, or portfolio admission.
