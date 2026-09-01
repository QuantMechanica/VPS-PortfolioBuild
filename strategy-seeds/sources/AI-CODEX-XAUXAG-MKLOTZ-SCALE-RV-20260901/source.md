---
source_id: AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901
title: XAU/XAG monthly centered Klotz scale-state reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed relationship and method records plus official exchange and NIST arithmetic
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_xauxag_monthly_klotz_scale_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
method_records:
  - KLOTZ-1962
  - NIST-KLOTZ-SCORE
  - NIST-KLOTZ-TEST
created: 2026-09-01
created_by: Research+Development
cards_extracted: []
---

# XAU/XAG Monthly Centered Klotz Scale-State Reversion

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_xauxag_monthly_klotz_scale_reversion_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one reputable-
source, structural low-frequency sleeve and identifies a market-neutral-style
gold/silver basket as an eligible route. This packet is bounded to one card,
one branch build, strict Q01, and one paced non-live logical-basket Q02
enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`,
   the governed complete-read record of Schweikert (2018), *Journal of
   Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   the official CME gold/silver ratio carrier record;
3. complete official NIST/SEMATECH Dataplot `KLOTZ SCORE` and `KLOTZ TEST`
   pages, including score, centering, statistic, approximation warning,
   examples, and notes; and
4. authoritative Crossref metadata for Jerome Klotz (1962), "Nonparametric
   Tests for Scale," *The Annals of Mathematical Statistics* 33(2), 498-512,
   DOI `10.1214/aoms/1177704576`.

The Project Euclid body route returned an Incapsula page, not the article.
That boundary is durable in `retrieval_route_klotz_1962_20260901.json`; no
complete-paper read or hidden body claim is made. Complete implementation
arithmetic comes from the official NIST pages, whose retrieval hashes and the
frozen `N=12` score table are in
`retrieval_route_nist_klotz_20260901.json`.

## Sources Of Record And Adverse Evidence

Schweikert supplies state-dependent and asymmetric gold/silver relationship
evidence. Its adverse findings remain binding: a constant relationship is not
uniformly supported, the relevant state is not known ex ante, and the paper
does not directly produce a forecast. It motivates a falsifiable relative-
value carrier, not a profitable mean-reversion claim.

CME defines the gold/silver ratio as gold price divided by silver price per
troy ounce and presents an opposed-leg intermarket spread. CME also separates
gold's larger monetary/safe-haven sensitivity from silver's larger industrial
cycle component. Equal target notionals are a QM translation; futures
clearing, offsets, contract ratios, and execution quality do not transfer to
Darwinex continuous CFDs.

NIST defines the Klotz score for pooled rank `R` among `N` observations as
`Phi^-1(R/(N+1))^2`. Its test page subtracts each sample's own mean before
pooling, then compares a sample's squared-normal-score sum with its equal-
label expectation and supplies a standardized numerator/denominator. NIST
explicitly says its critical values use a normal approximation and that
Dataplot does not compute exact critical values.

The EA therefore uses no NIST critical value or p-value. It freezes the
official score formula at `N=12`, enumerates all 924 fixed-size rank-label
assignments as a deterministic audit, and uses the inclusive upper half as a
disclosed activity boundary. That boundary is not source-reported inference.

## Source Claim Boundary

The sources jointly motivate one bounded question: when the centered
residuals of the latest six synchronized monthly gold/silver ratio changes
carry at least the upper-half Klotz squared-normal tail mass, does the recent
raw relative-return mean shift fade during the next broker month?

No source tests this conjunction. Thirteen synchronized endpoints, adjacent
log-ratio changes, fixed six/six blocks, separate block means, strict pooled
residual ties, frozen score literals, complete 924-label enumeration,
inclusive 494 boundary, raw-mean contrarian side, continuous-CFD mapping,
equal target notionals, fixed-dollar risk, hard stops, spreads, attempt
persistence, package atomicity, and lifecycle are pre-result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
hedge ratio, neutrality, CFD equivalence, significance, decorrelation, or
portfolio statistic transfers from any source.

## Exact Statistical Contract

At a broker-month transition reconstruct thirteen synchronized, positive,
finite, consecutive completed-month XAU/XAG close pairs. For chronological
endpoints `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old    = r[0..5]
recent = r[6..11]
mu_old    = sum(old) / 6
mu_recent = sum(recent) / 6
e_old[i]    = old[i]    - mu_old
e_recent[i] = recent[i] - mu_recent

require all twelve centered residuals finite and pairwise distinct under
tie_tol(a,b) = 1e-12 * max(1,abs(a),abs(b))

pool and sort the twelve residuals ascending, preserving old/recent labels
score[rank 1..12] =
  [2.0336952456315065,
   1.0405555206952889,
   0.54216113018145117,
   0.25240799405049096,
   0.086072547360949524,
   0.0093235661866525334,
   0.0093235661866525334,
   0.086072547360949524,
   0.25240799405049096,
   0.54216113018145117,
   1.0405555206952889,
   2.0336952456315065]

K_recent   = sum(score[rank] for the six recent residuals)
K_expected = 3.9642160041063397
K_den      = 1.2716448806860048
T1         = (K_recent - K_expected) / K_den
require finite K_recent and T1

tail_count = 0
assignment_count = 0
for every one of C(12,6)=924 choices of six recent ranks:
    K_perm = sum(the six frozen scores)
    if K_perm + 1e-12*max(1,abs(K_recent)) >= K_recent:
        tail_count++
    assignment_count++

require assignment_count == 924
require K_recent + 1e-12*max(1,abs(K_expected)) >= K_expected
require tail_count <= 494

delta = mu_recent - mu_old
tol_location = 1e-12 * max(1,abs(mu_old),abs(mu_recent))
SELL XAU / BUY XAG iff delta >  tol_location
BUY XAU / SELL XAG iff delta < -tol_location
FLAT otherwise
```

The frozen scores sum to `7.928432008212679`. Across all 924 six-rank
assignments, 430 are strictly above `K_expected`, 64 are on its symmetric
central support, and 430 are strictly below. The inclusive gate therefore
admits `494/924`, or `6.4155844` states per twelve unconstrained combinatorial
monthly attempts. This is a market-free activity prior, not a market
distribution, independence assumption, trade-count result, or efficacy
claim. Separate within-block centering constrains realized rank paths; Q02
must retire the card below five completed packages in any full post-warm-up
year.

## Locked Trading Translation

At the first synchronized executable `XAUUSD.DWX` D1 tick after a genuine
broker-month transition:

1. Normalize and persist current broker `yyyymm` before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month.
2. Exclude current-month prices. From a bounded 900-bar buffer select thirteen
   immediately prior consecutive broker months and the latest exactly
   timestamp-matched XAU/XAG D1 close pair in each. Reject missing, duplicate,
   unmatched, nonchronological, nonpositive, nonfinite, or endpoints more than
   ten calendar days from month end.
3. Calculate twelve adjacent log-ratio changes, preserve old/recent
   membership, subtract each block's own arithmetic mean, reject pooled
   residual ties, and assign only the frozen `N=12` Klotz scores.
4. Enumerate all 924 rank-label assignments and consume flat unless
   `K_recent` is on or above the frozen expectation, its inclusive upper tail
   is at most 494, and the raw block-mean shift is nonzero.
5. Fade a higher recent raw relative-return mean by selling XAU and buying
   XAG; fade a lower mean with the opposite package. Statistic magnitude and
   mean-shift magnitude never scale risk.
6. Open at most one opposed-leg equal-target-notional package under one
   aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   budget. Split frozen-stop risk equally, use `3.5*ATR(20,D1)` hard stops,
   reject XAU/XAG spreads above 1,500/500 points, and reject rounded target-
   notional mismatch above 20 percent.
7. Submit XAU first and XAG second. Keep exposure only when exactly one
   correct, stopped position exists under each registered magic; otherwise
   flatten every owned leg immediately.
8. Close the package on the first tick in a later broker month or after forty
   elapsed calendar days. No intramonth flip, convergence target, trail,
   break-even, partial close, Friday close, or news exit is authorized.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered native D1 history and timestamps, logarithms, sorting, bounded
integer loops, comparisons, broker calendar, quotes, metadata, ATR,
positions, deals, and terminal-persistent attempt state. It does not evaluate
an inverse-normal function at runtime.

## Non-Duplicate Functional Boundary

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_mklotz_scale_rv_preallocation_dedup_20260901.json`,
SHA-256
`2C5ECB7A982F2C7994F0F1B4EE362A34FB9CC789B53272CF41BB9C3ACC5D565D`,
found no exact identity across 4,768 registry rows, 1,405 card files, and all
45 Strategy Wiki nodes. It conservatively surfaced only
`QM5_41265_xauxag-mbf-scale-rv` and `QM5_41263_xauxag-mkuiper-rv`.

- `QM5_41265` centers raw changes on separate medians, compares the numeric
  means of absolute deviations, and uses the median shift for side. This rule
  centers on separate arithmetic means, discards residual spacing after
  ranking, applies nonlinear squared-normal scores, verifies a fixed-label
  upper half, and uses the raw mean shift for side.
- `QM5_41263` ranks uncentered raw changes, keeps two opposing ECDF maxima,
  and uses the raw recent rank sum for side. This rule ranks separately
  mean-centered residuals, aggregates all six recent nonlinear rank scores,
  and takes side from a raw block-mean difference independent of the scale
  ranks.
- `QM5_41260_xauxag-mad2-rv` accumulates all raw-change ECDF discrepancies
  with tail denominators and enumerates their statistic. This rule has no
  ECDF path; its only state value is a sum of six fixed centered-residual
  squared-normal scores.
- `QM5_41261_wti-mab-scale-tr` uses uncentered WTI returns and duplicated
  symmetric integer end-ranks, then continues cumulative return. This basket
  uses a different carrier, separate location removal, continuous nonlinear
  normal scores, and contrarian raw-mean direction.
- `QM5_41267_wti-mmood-scale-tr` uses uncentered WTI returns and squared
  distance from the pooled middle rank. This rule uses block-centered
  gold/silver relative returns and source-fixed normal quantiles, not
  polynomial rank distance.

Fixed no-tie fixtures prove functional disagreement:

```text
Klotz-only changes:
[2.5,0.5,-3.5,5.5,-1.5,-4.5, 3.5,1.5,-0.5,4.5,-5.5,-2.5]
mu_old/recent = -0.1666666667 / 0.1666666667
centered residual ranks for recent = [10,8,6,11,1,4]
K_recent = 3.964216004106340; tail = 494
Brown-Forsythe old/recent mean absolute deviation = 3.0 / 3.0
raw-change Kuiper = 1/3 with tail 922; Anderson-Darling tail = 924
=> Klotz SELL XAU / BUY XAG; all three fuzzy neighbors are flat.

Brown-Forsythe-only changes:
[5.0,-4.5,-1.0,6.5,3.5,2.5, -2.0,-3.0,8.0,-6.0,0.5,1.5]
mu_old/recent = 2.0 / -0.1666666667
K_recent = 3.674462867975379; tail = 566 => Klotz flat
Brown-Forsythe old/recent mean absolute deviation = 3.0 / 3.5
Brown-Forsythe medians = 3.0 / -0.75
=> Brown-Forsythe BUY XAU / SELL XAG; Klotz flat.

Side-disagreement changes:
[2.5,-0.5,1.5,3.5,-4.5,-3.5, -5.5,5.5,-2.5,0.5,4.5,-1.5]
mu_old/recent = -0.1666666667 / 0.1666666667
K_recent = 5.455750119556394; tail = 133
Brown-Forsythe medians = 0.5 / -0.5; deviations = 2.6666666667 / 3.3333333333
=> Klotz SELL XAU / BUY XAG while Brown-Forsythe buys XAU/sells XAG.
```

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_SEPARATE_MEAN_CENTERED_RESIDUAL_STRICT_RANK_FROZEN_KLOTZ_SQUARED_NORMAL_SCORE_EXACT_924_INCLUSIVE_UPPER_HALF_RAW_MEAN_SHIFT_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`: complete governed
  peer-reviewed gold/silver evidence with adverse findings, official exchange
  carrier evidence, authoritative peer-reviewed Klotz metadata with an
  explicit body-access boundary, complete official NIST arithmetic, hashes,
  and a durable AI origin trail.
- R2 `PASS`: clock, synchronization, endpoints, change orientation, block
  means, residuals, tie tolerance, rank direction, frozen scores, expectation,
  standardized diagnostic, all 924 labels, inclusive tolerance and boundary,
  side, attempt, aggregate risk, package atomicity, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5-native state provide every runtime
  input; basis, financing, calendar, and legging risks remain.
- R4 `PASS`: deterministic native arithmetic and framework state only; no
  trained output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire on a failed score, centering, rank, enumeration, or decision fixture;
an accepted tie; an assignment count other than 924; zero packages; fewer
than five completed packages in any full post-warm-up year; nonpositive
governed economics; downstream gate failure; or any month, endpoint,
synchronization, side, attempt, risk, package, lifecycle, or determinism
defect. Do not rescue a failure by changing the sample, split, centering,
score, boundary, side, carrier, risk, or hold.

Equal target notionals and opposite legs are market-neutral-style
construction only. They do not establish dollar, beta, volatility, factor,
market, or portfolio neutrality. Unchanged Q09 alone owns realized overlap.

Authorized after card G0 and deterministic registries: one branch-only
non-live build, reference tests, strict Q01, one canonical fixed-risk logical-
basket set plus component validation sets, and one paced logical-basket Q02
enqueue below the CPU ceiling. Excluded: manual tester run, optimization,
live/demo/shadow/stress preset, component-leg Q02 row, `T_Live`, AutoTrading,
deploy/live manifest, portfolio-gate change, portfolio admission, correlation
waiver, or terminal control.

## Revision History

| version | date | change | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | bounded carrier/method synthesis fixed before market testing | source approval | APPROVED_SOURCE |
