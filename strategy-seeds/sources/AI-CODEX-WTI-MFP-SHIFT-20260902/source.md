---
source_id: AI-CODEX-WTI-MFP-SHIFT-20260902
source_type: ai_originated_governed_synthesis
title: WTI monthly Fligner-Policello unequal-variance rank-shift continuation
author: OpenAI Codex
supporting_authors: Michael A. Fligner; George E. Policello II; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Grant Schneider; Eric Chicken; Rachel Becvarik
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_fligner_policello_shift_trend_source_approval.md
created: 2026-09-02
created_by: Codex
last_reviewed: 2026-09-02
cards_extracted:
  - wti-mfp-shift-tr
---

# WTI Monthly Fligner-Policello Rank-Shift Continuation

## Canonical origin and claim boundary

This is the single R1 lineage for one bounded AI-originated strategy under the
current explicit OWNER request for a new structural, low-frequency
commodity/energy sleeve. The idea was fixed before market testing: compare ten
older and ten recent completed WTI monthly log returns with the
Fligner-Policello unequal-shape rank-location score, then continue a sufficiently
large signed displacement for one month.

Moskowitz, Ooi, and Pedersen (2012) support only the WTI carrier, monthly
own-return continuation family, and monthly renewal. Fligner and Policello
(1981) support the named robust Behrens-Fisher rank-method lineage. The complete
pinned CRAN `NSM3` implementation supplies the exact operative pair-placement
score. Their trading conjunction is a transparent, untested QM synthesis.

No source tests this rule on a Darwinex continuous WTI CFD, fixes these two
ten-return blocks, uses `0.600` as an activity boundary, or supplies the fixed
risk, ATR stop, spread cap, consumed-attempt ledger, or lifecycle. No source
return, p-value, significance, Sharpe ratio, drawdown, trade count, cost,
CFD-equivalence, decorrelation, or portfolio statistic transfers.

## Supporting evidence and reproducibility

The complete governed trading-paper read is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
It records a complete 23-page read of *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. Appendix A explicitly includes NYMEX WTI;
the paper documents own-return continuation over monthly horizons, while also
making clear that the strongest security-level claim is not a WTI-only result.

Fligner and Policello (1981), *Robust Rank Procedures for the Behrens-Fisher
Problem*, *Journal of the American Statistical Association* 76(373), 162-168,
DOI `10.1080/01621459.1981.10477623`, supplies the named method and states the
purpose of testing median equality with fewer common-shape assumptions than
standard distribution-free tests. Only publisher metadata and the abstract
were available; the article body is not represented as read.

The complete operative method source is CRAN `NSM3` 1.20
`R/pFligPoli.R`, pinned at Git commit
`4f610ad57ca573f82a76f413455206b0ccce2ac2`, blob
`9a41229d88e5ff0173ca6ec3273a3ae0dcec0834`, content SHA-256
`D0633DB2F8780E431402030EB622D86536C841608961A57592F9CB9F21D6E060`.
It directly defines the pair placements, placement means, separate dispersion
sums, `p_bar*q_bar` term, denominator, and score orientation. Retrieval details
are in `retrieval_route_20260902.json`.

## Locked hypothesis and formula

Physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can shift WTI monthly-return location while changing dispersion.
When the ten newest completed monthly returns rank above or below the prior ten
under a score designed for unequal-shape samples, continue that direction for
the next broker month.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct twenty-one consecutive completed `XTIUSD.DWX` broker-month-end
   closes, oldest to newest, excluding all current-month prices.
2. Form twenty chronological log returns `r[0..19]`; set
   `old=r[0..9]`, `recent=r[10..19]`.
3. For each old return `x_i`, let `p_i` be the number of recent returns below
   it plus one half for every exact tie. For each recent return `y_j`, let
   `q_j` be the number of old returns below it plus one half for every exact
   tie.
4. Compute:

```text
p_bar = sum(p_i) / 10
q_bar = sum(q_j) / 10
v_p   = sum((p_i - p_bar)^2)
v_q   = sum((q_j - q_bar)^2)

numerator   = sum(q_j) - sum(p_i)
denominator = 2 * sqrt(v_p + v_q + p_bar*q_bar)
U_FP        = numerator / denominator
```

5. If `denominator <= 1e-12` and `numerator` is nonzero, use the finite
   directional limit `sign(numerator)*1e6`; if both are directionless, consume
   flat.
6. Buy only at `U_FP >= +0.600`; sell only at `U_FP <= -0.600`; otherwise
   consume flat. The score never changes risk.
7. Risk one fixed budget, attach a frozen `3.5*ATR(20,D1)` broker hard stop,
   and close at the next genuine broker month or after forty calendar days.

The `0.600` boundary is not a test significance level. Exact pre-data
enumeration over all `C(20,10)=184756` distinct-rank label allocations
qualifies `97,616`, or `52.8351%` and 6.340 theoretical attempts per twelve
monthly clocks. Receipt:
`artifacts/qm5_wti_mfp_shift_tr_threshold_density_20260902.json`.

## Non-duplicate boundary

The fail-closed canonical checker scanned 4,783 registry rows, 1,419 cards,
and 45 Strategy Wiki nodes. It found no exact identity and raised two fuzzy
neighbors for mandatory manual review. Receipt:
`artifacts/qm5_wti_mfp_shift_tr_preallocation_dedup_20260902.json`.

- `QM5_41183_wti-mks-shift-tr` takes the single largest signed ECDF gap from
  two six-price blocks. This rule averages all cross-block return placements,
  estimates placement dispersion, uses ten-by-ten blocks, and has no ECDF
  supremum.
- `QM5_41251_wti-mbrunner-shift-tr` uses pooled-versus-within midranks and the
  corrected Brunner-Munzel relative-effect studentizer. This rule uses the
  Fligner-Policello `p_i/q_j` dispersion and `p_bar*q_bar` denominator. On
  recent ranks `(1,2,3,4,5,6,17,18,19,20)`, this rule sells at
  `-0.6154574549`, while the locked Brunner-Munzel neighbor is flat at
  `-0.6123724357` versus its `0.625` boundary.
- `QM5_41176_wti-mwilcoxon-shift-tr` thresholds one unstudentized cross-pair
  count. Equal Mann-Whitney totals can differ here: recent-rank allocations
  `(1,2,3,4,5,11,13,18,19,20)` and
  `(1,2,3,4,5,11,14,17,19,20)` both have `U_new=41`, but their scores are
  `-0.5986843401` (flat) and `-0.6040540547` (sell).
- `QM5_41249_wti-mwelch-shift-tr` uses raw means and raw variances; this score
  is invariant to strictly monotone transformation of the pooled returns.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only short-horizon XNG
  oscillator pullback, not a symmetric monthly direct-WTI rank shift.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_FLIGNER_POLICELLO_UNEQUAL_SHAPE_RANK_LOCATION_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_METHOD_BODY_BOUNDARY`: one durable AI source
  ID, a complete governed peer-reviewed WTI paper read, original peer-reviewed
  method metadata/abstract, and a complete pinned official package
  implementation. The exact trading conjunction is explicitly untested.
- R2 `PASS`: clock, endpoints, returns, fixed blocks, exact tie placements,
  score, degeneracy rule, threshold, side, attempt, fixed risk, stop, spread,
  and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 and MT5 state supply every runtime input; roll, financing,
  basis, gaps, and broker-month labels remain risks.
- R4 `PASS`: completed prices, logarithms, comparisons, sums, squares, square
  roots, ATR risk control, and native execution state only; no ML, trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. Q02 kills zero positions,
fewer than five completed positions in any full post-warm-up scored year,
nonpositive governed economics, leakage, or deterministic-fixture failure.
Q09 alone owns realized portfolio overlap. No post-result change to samples,
formula, threshold, carrier, direction, stop, or hold may rescue failure.

Authorized scope is one card, one branch-only non-live build, strict Q01, and
one paced Q02 enqueue if the whole-host CPU ceiling permits. It excludes a
manual tester run, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy/live manifests, portfolio-gate edits, correlation waivers,
and portfolio admission.
