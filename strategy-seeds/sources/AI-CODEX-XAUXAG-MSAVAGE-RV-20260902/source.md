---
source_id: AI-CODEX-XAUXAG-MSAVAGE-RV-20260902
title: XAU/XAG monthly centered-Savage-score reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed relationship evidence and official exchange/statistical method records
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_xauxag_monthly_savage_score_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
method_records:
  - NIST-TWO-SAMPLE-LINEAR-RANK-SAVAGE
  - SAS-NPAR1WAY-SAVAGE-SCORES-EXACT
  - SAVAGE-1956-JOURNAL-METADATA
created: 2026-09-02
created_by: Research+Development
cards_extracted:
  - QM5_41279_xauxag-msavage-rv
---

# XAU/XAG Monthly Centered-Savage-Score Reversion

## Approval And Complete Read

The durable source approval is
`decisions/2026-09-02_xauxag_monthly_savage_score_reversion_source_approval.md`,
commit `c8ac8a822f`. The current explicit OWNER commodity/energy mission
authorizes one reputable-source, structural low-frequency sleeve and names a
market-neutral-style gold/silver basket as an eligible route. This packet is
bounded to one card, one branch build, strict Q01, and one paced non-live
logical-basket Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`,
   the governed complete-read record of Schweikert (2018), *Journal of
   Banking & Finance* 88, 44-51;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   the official CME gold/silver-ratio carrier record;
3. the complete bounded NIST/SEMATECH two-sample linear-rank sections;
4. the complete bounded SAS/STAT NPAR1WAY score chapter and exact Savage-test
   option; and
5. authoritative JSTOR metadata for I. Richard Savage (1956),
   *The Annals of Mathematical Statistics* 27(3), 590-615. The original
   article body is not claimed as a complete read.

Exact URLs, response metadata, hashes, read scopes, constants, and claim
boundaries are in `retrieval_route_savage_scores_20260902.json`.

## Sources Of Record And Adverse Evidence

Schweikert finds a state-dependent and asymmetric gold/silver relation.
Constant-vector cointegration fails in important specifications, some daily
upper quantiles reject quantile cointegration, the relevant state is not
known ex ante, and the estimates do not directly produce a forecast. This is
adverse evidence against treating the ratio as a stable deterministic spread.

CME defines the gold/silver ratio as gold price divided by silver price per
troy ounce and describes an opposed-leg intermarket spread. It also separates
gold's monetary/safe-haven demand from silver's larger industrial-cycle
exposure. Futures liquidity, margin offsets, and execution quality do not
transfer to continuous CFDs.

NIST and SAS independently define the centered Savage score

```text
a(r) = sum[j=1..r] 1/(N-j+1) - 1
```

as a linear-rank score derived from exponential order statistics. SAS
documents an exact two-sample Savage test based on the rank-score sum. The
official records define arithmetic and method identity only. They do not
define a market carrier, sample, threshold, side, hold, or risk model.

## Source Claim Boundary

The records jointly motivate one bounded question: when the latest six
synchronized monthly gold/silver ratio changes carry an extreme centered
Savage rank-score sum relative to the prior six, does fading that extreme
rank displacement during the next broker month produce a viable relative-
value return stream?

No source tests this conjunction. Thirteen synchronized endpoints, adjacent
log-ratio changes, fixed six/six chronological blocks, strict tie rejection,
the complete 924-label absolute-score enumeration, the inclusive 462-tail
activity boundary, contrarian score-sign side, continuous-CFD mapping, equal
target notionals, fixed-dollar risk, hard stops, spread ceilings, attempt
persistence, package atomicity, and lifecycle are pre-result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
hedge ratio, neutrality, CFD equivalence, p-value, critical value,
decorrelation, or portfolio statistic transfers from any source.

## Exact Statistical Contract

At a broker-month transition reconstruct thirteen synchronized, positive,
finite, consecutive completed-month XAU/XAG close pairs. For chronological
endpoints `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old    = r[0..5]
recent = r[6..11]

require all twelve changes finite and pairwise distinct under
tie_tol(a,b) = 1e-12 * max(1,abs(a),abs(b))

pool and sort the twelve changes ascending
R = the six pooled ranks 1..12 carried by recent observations

for rank r=1..12:
    a(r) = sum[j=1..r] 1/(12-j+1) - 1

S = sum[a(r) for r in R]

assignment_count = 0
tail_count = 0
for every one of C(12,6)=924 choices P of six recent ranks:
    S_perm = sum[a(r) for r in P]
    if abs(S_perm) + 1e-12*max(1,abs(S)) >= abs(S):
        tail_count++
    assignment_count++

require assignment_count == 924
require tail_count <= 462

BUY XAU / SELL XAG iff S < 0
SELL XAU / BUY XAG iff S > 0
FLAT iff S is zero within relative tolerance
```

For audit-stable verification, the twelve score numerators over denominator
`27720` are:

```text
rank:       1      2      3      4      5      6      7    8     9     10     11     12
numerator: -25410 -22890 -20118 -17038 -13573 -9613 -4993  551  7481  16721  30581  58301
```

Their total is zero. Across all 924 strict six-rank assignments, absolute
score values occur in exact complementary pairs and none is zero. The
inclusive tail cap 462 admits exactly 462 assignments at or beyond exact
boundary `15991/13860 = 1.1537518037518038`: 231 positive and 231 negative,
or six directional states per twelve combinatorial attempts. This is a
market-free activity prior only. Q02 must retire below five completed
packages in any full post-warm-up year.

## Locked Trading Translation

At the first synchronized executable `XAUUSD.DWX` D1 tick after a genuine
broker-month transition:

1. Persist the current broker `yyyymm` attempt before fallible gates. Never
   retry the month.
2. Exclude current-month prices. From a bounded 900-bar buffer select the
   thirteen immediately prior consecutive broker months and the latest exact
   timestamp-matched XAU/XAG D1 close pair in each.
3. Calculate the twelve adjacent gold-minus-silver log-ratio changes,
   preserve fixed old/recent membership, reject pooled ties, and assign strict
   ascending ranks.
4. Compute the locked centered Savage score sum and enumerate all 924 fixed-
   size rank assignments. Consume flat unless the inclusive absolute-score
   tail is at most 462 and the score is nonzero.
5. Fade a positive recent score by selling XAU and buying XAG; fade a
   negative score with the opposite package. Score magnitude never scales
   risk.
6. Open at most one opposed-leg equal-target-notional package under one
   aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   budget. Split frozen-stop risk equally, use `3.5*ATR(20,D1)` hard stops,
   reject XAU/XAG spreads above 1,500/500 points, and reject rounded target-
   notional mismatch above 20 percent.
7. Submit XAU first and XAG second. Keep exposure only when exactly one
   correctly sided stopped position exists under each registered magic;
   otherwise flatten all owned exposure immediately.
8. Close both legs on the first tick in a later broker month or after forty
   elapsed calendar days. No intramonth flip, target, trail, break-even,
   partial close, Friday close, scale-in, or pyramid is authorized.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered native D1 history and timestamps, logarithms, sorting, bounded
integer loops, harmonic arithmetic, comparisons, broker state, ATR, quotes,
metadata, positions, deals, and terminal-persistent attempt state.

## Non-Duplicate Functional Boundary

The corrected-root receipt
`artifacts/qm5_xauxag_msavage_rv_preallocation_dedup_20260902.json`, SHA-256
`86611AD596DBE2036EF5F27F108E9E478E5D6E24C34BB022FE5350EF43414EBE`,
found no exact identity across 4,778 registry rows, 1,414 cards, and all 45
Strategy Wiki nodes. It surfaced five expected shared-carrier cards.

- `QM5_41278` combines squared raw ranks and squared contrary-ranks through
  Cucconi's strong negative correlation.
- `QM5_41260` integrates a tail-weighted Anderson-Darling ECDF discrepancy.
- `QM5_41263` retains only Kuiper's two opposing ECDF extrema.
- `QM5_41265` preserves numeric median-centered absolute deviations.
- `QM5_41269` separately mean-centers blocks and applies symmetric squared-
  normal scores.

This source uses none of those paths, centers, deviations, or symmetric
scores. Its monotone harmonic score heavily distinguishes the top ranks and
keeps the score sign as direction. Fixed fixtures lock disagreement:

```text
RRROOOOOORRR:
  Savage S=+1.3414502164502164, tail=400 => SELL XAU
  recent rank sum=39; Cucconi, AD2, Kuiper, raw rank-sum side, centered Klotz => flat

RRRROOOROOOR:
  Savage S=-0.9597402597402600, tail=536 => flat
  Cucconi tail=88, AD2 tail=110, Kuiper tail=108 => BUY XAU

RRRROOOOROOR:
  Savage S=-0.7097402597402600, tail=632 => flat
  centered Klotz score=6.410233092890735, tail=26 => BUY XAU
```

`O`/`R` label pooled ascending old/recent observations. Complement paths lock
BUY/SELL symmetry. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_CENTERED_SAVAGE_HARMONIC_EXPONENTIAL_ORDER_SCORES_EXACT_924_ABSOLUTE_TAIL_462_SCORE_SIGN_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE`: durable source
  approval; complete governed peer-reviewed carrier evidence and adverse
  findings; official exchange evidence; complete bounded NIST and SAS
  formula/exact-test sections; original method metadata; hashes and explicit
  claim boundary.
- R2 `PASS`: clock, synchronization, endpoints, changes, ties, ranks, scores,
  complete enumeration, inclusive tail, sign side, attempt, aggregate risk,
  atomicity, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5-native state provide all runtime inputs.
- R4 `PASS`: deterministic native arithmetic only; no trained output,
  prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Falsification And Safety Boundary

Retire on a failed score or enumeration fixture, an accepted pooled tie, an
assignment count other than 924, zero packages, fewer than five completed
packages in any full post-warm-up year, nonpositive governed economics,
downstream gate failure, or any synchronization, attempt, risk, package, or
lifecycle defect. Do not rescue a failure by changing the sample, statistic,
tail, side, carrier, risk, or hold.

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
| v1 | 2026-09-02 | bounded carrier/method synthesis fixed before market testing | source approval | APPROVED_SOURCE |
