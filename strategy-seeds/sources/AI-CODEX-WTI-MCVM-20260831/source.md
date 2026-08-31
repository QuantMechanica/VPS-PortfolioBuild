---
source_id: AI-CODEX-WTI-MCVM-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly exact-permutation integrated-ECDF distribution-shift continuation
author: OpenAI Codex
supporting_authors: T. W. Anderson; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_mcvm_distribution_shift_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted: []
---

# WTI Monthly Exact-Permutation Integrated-ECDF Distribution-Shift Continuation

## Canonical origin and prompt trail

This is the single R1 lineage for one bounded AI-originated strategy. The
current explicit OWNER mission requests one new structural, low-frequency
commodity/energy sleeve outside the certified XAU/SP500/NDX/XNG carrier set,
names direct WTI trend/seasonality as an eligible route, requires reputable-
source criteria and a fixed-risk baseline, and authorizes a branch-only build
plus one paced Q02 enqueue.

Codex fixed the mechanic below before any market test. It is an untested QM
synthesis, not a reported WTI strategy and not a claim that a statistical
test has discovered alpha.

## Supporting evidence and access boundary

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It supports only NYMEX WTI membership,
monthly decisions, and own-return continuation. It does not test this signal.

T. W. Anderson (1962), *On the Distribution of the Two-Sample Cramer-von
Mises Criterion*, *The Annals of Mathematical Statistics* 33(3), 1148-1159,
DOI `10.1214/aoms/1177704477`, is bibliographic method context only. The
deterministic generic-source router returned `DEFERRED:SOURCE_POLICY`; receipt:
`retrieval_route_20260831.json`. No inaccessible article text, critical value,
asymptotic distribution, empirical result, or significance statement is
imported.

The operative integrated squared ECDF-rank path, exact 924-label enumeration,
tail boundary, recent-median direction, WTI CFD translation, stop, risk, and
lifecycle below are disclosed QM choices.

## Locked hypothesis

Physical supply, production, storage, transport, refining, hedging,
geopolitical, and demand shocks can displace the distribution of WTI monthly
returns. When the newest six completed returns differ broadly from the prior
six across their pooled empirical-distribution path, continue the recent
block's median direction for one monthly package.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct exactly thirteen consecutive completed `XTIUSD.DWX` broker-
   month end closes, oldest to newest, excluding every current-month price.
2. Form twelve adjacent finite log returns. The oldest six are the fixed old
   sample; the newest six are the fixed recent sample.
3. Require all twelve returns to be pairwise distinct. Sort the pooled returns
   ascending while preserving fixed sample membership.
4. After every pooled rank, update old and recent counts. Let
   `delta_k=old_seen_k-recent_seen_k` and compute the integer integrated path
   score `S=sum(delta_k^2)` over all twelve ranks. The final zero term is kept
   for audit symmetry and does not change the score.
5. Enumerate every one of the `C(12,6)=924` possible assignments of six pooled
   ranks to the pseudo-recent sample. Recompute `S` for each assignment and
   count assignments with `S_perm >= S_observed`.
6. Consume flat unless the enumeration count is exactly 924 and the inclusive
   upper-tail count is at most 460. Equivalently, the observed integer score
   is at least 22. Exact enumeration proves that 460 of 924 strict rank paths
   qualify before market data; this is an activity boundary, not a p-value or
   significance claim.
7. Compute the ordinary even-sample median of each actual fixed block. Buy
   when `median_recent-median_old > 1e-12`, sell below `-1e-12`, and consume
   flat otherwise. Score magnitude never scales risk.
8. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 1,500-point spread ceiling.
9. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off.

## Non-duplicate boundary

The corrected-root canonical checker scanned 4,754 registry identities,
1,392 card files, and 45 Strategy Wiki nodes. It found no exact identity and
one fuzzy method neighbor. Receipt:
`artifacts/qm5_wti_mcvm_shift_tr_preallocation_dedup_20260831.json`.

- `QM5_41250_wti-mperm-scale-tr` enumerates the same number of fixed-size
  labelings but tests recent-minus-old median absolute deviation. A pure
  location shift with unchanged within-block dispersion is flat there and can
  qualify here; a symmetric scale expansion with unchanged medians can qualify
  there and is directionless here.
- `QM5_41183_wti-mks-shift-tr` uses completed month-end price levels and only
  the greatest signed ECDF gap. This rule uses adjacent monthly returns and
  integrates every squared ECDF path deviation before an exact permutation
  boundary.
- `QM5_41176_wti-mwilcoxon-shift-tr` uses a rank-sum/location functional; this
  rule depends on the full cumulative membership path and can separate paths
  having the same rank sum.
- `QM5_41249_wti-mwelch-shift-tr` standardizes an arithmetic-mean difference
  by sample variances; this rule uses neither means nor variances to qualify.
- `QM5_41251_wti-mbrunner-shift-tr` uses standardized rank-placement means and
  placement variances; this rule uses an unstandardized integrated path and
  an exact full assignment distribution.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly WTI structural shift.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_INTEGRATED_SQUARED_ECDF_PATH_EXACT_924_LABEL_TAIL460_RECENT_MEDIAN_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY`: exactly one durable AI
  source ID and prompt/output trail; complete-read peer-reviewed WTI evidence
  supports only carrier/cadence/direction; the method citation is explicitly
  deferred and transfers no content claim.
- R2 `PASS`: clock, endpoints, returns, fixed samples, tie rule, pooled path,
  score, complete enumeration, tail boundary, direction, attempt, fixed risk,
  stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state supply all runtime inputs; roll,
  financing, gaps, and broker-month-label risks remain.
- R4 `PASS`: completed prices, logarithms, finite comparisons, sorting,
  integer enumeration, medians, ATR risk control, and native position/deal
  state only; no ML, trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. Q02 retires zero trades,
any full scored post-warm-up year below five completed positions, nonpositive
governed economics, future leakage, or a deterministic-fixture failure. Q09
alone owns realized portfolio overlap. Failure may not be rescued by changing
the sample size, return definition, score, tail boundary, direction, stop, or
hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if the whole-host CPU ceiling permits. It authorizes
no manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or live manifest, portfolio-gate mutation, correlation
waiver, or portfolio admission.
