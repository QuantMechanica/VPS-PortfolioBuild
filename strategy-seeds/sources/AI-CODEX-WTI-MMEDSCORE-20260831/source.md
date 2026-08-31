---
source_id: AI-CODEX-WTI-MMEDSCORE-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly exact median-score location-shift continuation
author: OpenAI Codex
supporting_authors: George W. Brown; Alexander M. Mood; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_monthly_median_score_shift_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted: []
---

# WTI Monthly Exact Median-Score Location-Shift Continuation

## Canonical origin and prompt trail

This is the single R1 lineage for one bounded AI-originated strategy. The
current explicit OWNER mission requests one new structural, low-frequency
commodity/energy sleeve outside the certified XAU/SP500/NDX/XNG carrier set,
names direct WTI trend/seasonality as an eligible route, requires reputable-
source criteria and a fixed-risk baseline, and authorizes a branch-only build
plus one paced Q02 enqueue.

Codex fixed the mechanic below before any market test. It is an untested QM
synthesis, not a reported WTI strategy and not a claim that a statistical test
has discovered alpha.

## Supporting evidence and access boundary

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It supports only WTI membership, monthly
decisions, and own-return continuation. It does not test this signal.

Brown and Mood (1951), *On Median Tests for Linear Hypotheses*, Proceedings of
the Second Berkeley Symposium on Mathematical Statistics and Probability,
159-166, and the NIST Dataplot median-test page are bibliographic method
context only. The deterministic generic-source router returned
`DEFERRED:SOURCE_POLICY` for the NIST page; receipt:
`retrieval_route_20260831.json`. No inaccessible article or web-page content,
formula, critical value, asymptotic result, or empirical finding is imported.

The operative fixed-rank median score, exact 924-label enumeration, tail
boundary, direction, WTI CFD translation, stop, risk, and lifecycle below are
disclosed QM choices.

## Locked hypothesis

Physical supply, production, storage, transport, refining, hedging,
geopolitical, and demand shocks can displace the center of WTI monthly returns.
When at least five of the newest six completed returns occupy the upper half of
the pooled old-versus-new sample, continue the positive shift for one monthly
package; symmetrically continue a lower shift.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct exactly thirteen consecutive completed `XTIUSD.DWX` broker-
   month end closes, oldest to newest, excluding every current-month price.
2. Form twelve adjacent finite log returns. The oldest six are the fixed old
   sample; the newest six are the fixed recent sample.
3. Require all twelve returns to be pairwise distinct. Sort the pooled returns
   ascending while retaining fixed sample membership. The grand-median boundary
   lies strictly between ranks 6 and 7.
4. Let `H` be the number of actual recent returns occupying ranks 7 through 12.
5. Enumerate all `C(12,6)=924` assignments of six ranks to a pseudo-recent
   sample. For each assignment compute `H_perm` and count it as at least as
   extreme when `abs(H_perm-3) >= abs(H-3)`.
6. Require exactly 924 assignments and an inclusive exact tail count at most
   74. This is equivalent to `H<=1` or `H>=5`, because the two tails contain
   `2*(C(6,0)^2+C(6,1)^2)=74` assignments.
7. Buy for `H>=5`, sell for `H<=1`, and consume flat otherwise. Count or tail
   magnitude never scales risk.
8. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 1,500-point spread ceiling.
9. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off.

## Non-duplicate boundary

The corrected-root canonical checker scanned 4,755 registry identities, 1,393
card files, and 45 Strategy Wiki nodes. It found no exact identity and two
fuzzy method neighbors. Receipt:
`artifacts/qm5_wti_mmedscore_shift_tr_preallocation_dedup_20260831.json`.

- `QM5_41255_wti-mcvm-shift-tr` integrates squared membership imbalance after
  every pooled rank. This rule retains only how many recent observations are
  above the grand median; it deliberately discards all within-half ordering.
- `QM5_41250_wti-mperm-scale-tr` tests a within-block median-absolute-deviation
  difference and follows a recent mean. This rule tests a pooled location score
  and never computes block dispersion or means.
- `QM5_41137_wti-mmedian-shift-mom` acts on any nonzero two-block median
  difference. This rule requires an extreme pooled upper-half count and can be
  flat despite separated block medians.
- `QM5_41176_wti-mwilcoxon-shift-tr` counts every recent-versus-old pairwise
  win. This rule ignores all rank distance within each pooled half; paths can
  share `H` while having different Mann-Whitney scores.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly WTI structural shift.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_POOLED_GRAND_MEDIAN_SCORE_EXACT_924_TAIL74_LOCATION_SHIFT_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY`: exactly one durable AI
  source ID and prompt/output trail; complete-read peer-reviewed WTI evidence
  supports only carrier/cadence/direction; method references transfer no
  inaccessible content claim.
- R2 `PASS`: clock, endpoints, returns, fixed samples, tie rule, pooled order,
  score, complete enumeration, tail boundary, direction, attempt, fixed risk,
  stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1
  history and MT5 state supply all runtime inputs; roll, financing, gaps, and
  broker-month-label risks remain.
- R4 `PASS`: completed prices, logarithms, finite comparisons, sorting, integer
  enumeration, ATR risk control, and native position/deal state only; no ML,
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. Q02 retires zero trades, any
full scored post-warm-up year below five completed positions, nonpositive
governed economics, future leakage, or a deterministic-fixture failure. Q09
alone owns realized portfolio overlap. Failure may not be rescued by changing
the sample size, score, exact tail boundary, direction, stop, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if the whole-host CPU ceiling permits. It authorizes
no manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or live manifest, portfolio-gate mutation, correlation waiver,
or portfolio admission.
