---
source_id: AI-CODEX-XAUXAG-MCUCCONI-RV-20260902
title: XAU/XAG monthly Cucconi location-scale-state reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed relationship and method records plus official exchange evidence
source_type: ai_originated_peer_reviewed_exchange_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_xauxag_monthly_cucconi_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
method_records:
  - MAROZZI-CUCCONI-2012-COMPLETE
  - MAROZZI-CUCCONI-2009-METADATA
created: 2026-09-02
created_by: Research+Development
cards_extracted:
  - QM5_41278_xauxag-mcucconi-rv
---

# XAU/XAG Monthly Cucconi Location-Scale-State Reversion

## Approval And Complete Read

The durable source approval is
`decisions/2026-09-02_xauxag_monthly_cucconi_reversion_source_approval.md`,
commit `3cad3fab48`. The current explicit OWNER commodity/energy mission
authorizes one reputable-source, structural low-frequency sleeve and names a
market-neutral-style gold/silver basket as an eligible route. This packet is
bounded to one card, one branch build, strict Q01, and one paced non-live
logical-basket Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`,
   the governed complete-read record of Schweikert (2018), *Journal of
   Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   the official CME gold/silver ratio carrier record;
3. Marozzi (2012), "A modified Cucconi Test for Location and Scale Change
   Alternatives," *Revista Colombiana de Estadistica* 35(3), 371-384,
   complete 14-page publisher PDF, SHA-256
   `236BA86C34B99F126CA6EECB16CEA9082EEACA4D0F1D90406853BB059A2C0BEB`;
   and
4. complete authoritative Crossref metadata for Marozzi (2009), "Some notes
   on the location-scale Cucconi test," *Journal of Nonparametric
   Statistics* 21(5), 629-647, DOI `10.1080/10485250902952435`.

The exact URLs, response metadata, hashes, read scope, constants, and claim
boundary are in
`retrieval_route_marozzi_cucconi_20260902.json`. The 2012 publisher PDF was
read end to end: abstract, motivation, original Cucconi construction and
moments, asymptotic geometry, fixed-label permutation construction, modified
test, simulations, application, conclusion, and references. The 2009 body is
not claimed as complete-read because the complete 2012 paper supplies the
implementation arithmetic directly.

## Sources Of Record And Adverse Evidence

Schweikert finds a state-dependent and asymmetric gold/silver relation. The
adverse findings are load-bearing: constant-vector cointegration fails in
important specifications, some daily upper quantiles reject quantile
cointegration, the relevant state is not known ex ante, and the estimates do
not directly produce a forecast. The paper motivates a falsifiable relative-
value carrier, not profitable mean reversion.

CME defines the gold/silver ratio as gold price divided by silver price per
troy ounce and describes an opposed-leg intermarket spread. CME also separates
gold's greater monetary/safe-haven sensitivity from silver's larger industrial
cycle exposure. Equal target notionals are a QM translation. Futures margin
offsets, contract ratios, liquidity, and execution quality do not transfer to
Darwinex continuous CFDs.

Marozzi states the original Cucconi location-scale statistic in terms of one
sample's pooled squared ranks and squared contrary-ranks, their expectations,
unit-variance standardization, and strong negative correlation. The paper
also defines the exact fixed-label permutation tail over
`K=N!/(n1!*n2!)` assignments. Its examples and size/power results are
biomedical/statistical evidence only. They do not establish a market signal,
threshold, direction, holding period, or return.

## Source Claim Boundary

The records jointly motivate one bounded question: when the distribution of
the latest six synchronized monthly gold/silver ratio changes differs from the
prior six under a high classical Cucconi squared-rank/contrary-rank state,
does the ordinal location direction fade during the next broker month?

No source tests this conjunction. Thirteen synchronized endpoints, adjacent
log-ratio changes, fixed six/six chronological blocks, strict tie rejection,
the complete 924-label enumeration, the inclusive 480-tail activity boundary,
the neutral rank-sum rule, contrarian side, continuous-CFD mapping, equal
target notionals, fixed-dollar risk, hard stops, spread ceilings, attempt
persistence, package atomicity, and lifecycle are pre-result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
hedge ratio, neutrality, CFD equivalence, statistical significance,
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

N = 12; n1 = 6; n2 = 6
E2  = n1*(N+1)*(2*N+1)/6 = 325
SD2 = sqrt(n1*n2*(N+1)*(2*N+1)*(8*N+11)/180)
    = sqrt(6955)
    = 83.3966426182733
rho = 2*(N^2-4)/((2*N+1)*(8*N+11)) - 1
    = -479/535
    = -0.8953271028037383

U = (sum(R^2) - E2) / SD2
V = (sum((N+1-R)^2) - E2) / SD2
C = (U^2 + V^2 - 2*rho*U*V) / (2*(1-rho^2))
require U,V,C finite and C nonnegative within relative tolerance

tail_count = 0
assignment_count = 0
for every one of C(12,6)=924 choices of six recent ranks:
    compute U_perm, V_perm, C_perm from the same constants
    if C_perm + 1e-12*max(1,abs(C)) >= C:
        tail_count++
    assignment_count++

require assignment_count == 924
require tail_count <= 480

W_recent = sum(R)
BUY XAU / SELL XAG iff W_recent < 39
SELL XAU / BUY XAG iff W_recent > 39
FLAT iff W_recent == 39
```

The smallest statistic admitted by the exact tail cap is
`0.7655677655677652`. Across all 924 strict six-rank labels, 480 assignments
pass the statistic gate. Eighteen of those have neutral recent rank sum 39,
leaving exactly 462 directional assignments, or six states per twelve
combinatorial attempts. This is a market-free activity prior. It is not a
market distribution, serial-independence assumption, trade-count result, or
efficacy claim. Q02 must retire below five completed packages in any full
post-warm-up year.

## Locked Trading Translation

At the first synchronized executable `XAUUSD.DWX` D1 tick after a genuine
broker-month transition:

1. Persist the current broker `yyyymm` attempt before history, signal, news,
   spread, quote, ATR, sizing, margin, or order gates. Never retry the month.
2. Exclude current-month prices. From a bounded 900-bar buffer select the
   thirteen immediately prior consecutive broker months and the latest exact
   timestamp-matched XAU/XAG D1 close pair in each. Reject missing,
   duplicated, unmatched, nonchronological, nonpositive, nonfinite, or stale
   endpoints.
3. Calculate the twelve adjacent gold-minus-silver log-ratio changes, preserve
   fixed old/recent membership, reject pooled ties, and assign strict ascending
   ranks.
4. Compute the locked classical Cucconi statistic and enumerate all 924
   fixed-size rank assignments. Consume flat unless the inclusive tail is at
   most 480 and the recent rank sum is not 39.
5. Fade high recent ranks by selling XAU and buying XAG; fade low recent ranks
   with the opposite package. Statistic magnitude and rank-sum distance never
   scale risk.
6. Open at most one opposed-leg equal-target-notional package under one
   aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   budget. Split frozen-stop risk equally, use `3.5*ATR(20,D1)` hard stops,
   reject XAU/XAG spreads above 1,500/500 points, and reject rounded target-
   notional mismatch above 20 percent.
7. Submit XAU first and XAG second. Keep exposure only when exactly one
   correctly sided stopped position exists under each registered magic;
   otherwise flatten all owned exposure immediately.
8. Close both legs on the first tick in a later broker month or after forty
   elapsed calendar days. No intramonth flip, target convergence exit, trail,
   break-even, partial close, Friday close, or news exit is authorized.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered native D1 history and timestamps, logarithms, sorting, bounded
integer loops, comparisons, broker calendar, quotes, metadata, ATR,
positions, deals, and terminal-persistent attempt state.

## Non-Duplicate Functional Boundary

The corrected-root receipt
`artifacts/qm5_xauxag_mcucconi_rv_preallocation_dedup_20260902.json`, SHA-256
`7410C6B9B94B9B3E5BF1E5964789C42471DA5016F643149624FF4C29DF2B8DE8`,
found no exact identity across 4,777 registry rows, 1,413 cards, and all 45
Strategy Wiki nodes. It conservatively surfaced four shared-carrier cards.

- `QM5_41263_xauxag-mkuiper-rv` retains two opposing ECDF extrema and uses a
  broad fixed Kuiper distance/tail gate. This rule reduces the whole recent
  label set to correlated squared rank and contrary-rank sums.
- `QM5_41260_xauxag-mad2-rv` integrates a tail-weighted ECDF discrepancy over
  every pooled-rank cut. This rule has no ECDF path or cut weights.
- `QM5_41265_xauxag-mbf-scale-rv` preserves numeric deviations from separate
  block medians. This rule discards all spacing after strict raw-change ranks.
- `QM5_41269_xauxag-mklotz-scale-rv` removes each block mean before ranking
  and applies nonlinear frozen squared-normal scores. This rule does not
  center either block and uses classical squared integer ranks plus contrary-
  ranks with their exact negative-correlation correction.
- `QM5_41270_wti-mlepage-shift-tr` uses a different carrier, 25-by-25 daily
  samples, independent Wilcoxon/Ansari-Bradley components, and continuation.
  Cucconi is not that component sum and this card is contrarian XAU/XAG.

Fixed strict-rank fixtures lock disagreement:

```text
RROROROOORRO:
  Cucconi C=0.7655677655677652, tail=480, rank_sum=34 => BUY XAU
  Anderson-Darling tail=532 => flat

RROROROROROO:
  Cucconi C=0.8205128205128197, tail=456, rank_sum=31 => BUY XAU
  Kuiper V=1/3, tail=922 => flat

RRRRROOROOOO:
  Cucconi C=3.287545787545790, tail=14, rank_sum=23 => BUY XAU
  Klotz score=3.674462867975380, tail=566 => flat

RROROROROORO:
  Cucconi C=0.716117216117216, tail=484 => flat
  Klotz score=4.253969140237301, tail=374 => BUY XAU
```

Here `O` and `R` label pooled ascending old and recent observations. Complement
paths lock the symmetric SELL decisions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_CUCCONI_SQUARED_RANK_CONTRARY_RANK_CORRELATED_QUADRATIC_EXACT_924_TAIL_480_RANK_SUM_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`: durable source
  approval; complete governed peer-reviewed gold/silver evidence and adverse
  findings; official exchange carrier evidence; complete peer-reviewed
  publisher PDF containing the classical formula and exact permutation
  construction; authoritative metadata, hashes, and explicit claim boundary.
- R2 `PASS`: clock, synchronization, endpoints, change orientation, block
  membership, ties, ranks, squared sums, constants, statistic, all 924 labels,
  inclusive boundary, side, attempt, aggregate risk, atomicity, and lifecycle
  are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5-native state provide every runtime
  input; basis, financing, calendar, and legging risks remain.
- R4 `PASS`: deterministic native arithmetic and framework state only; no
  trained output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire on a failed statistic, moment, correlation, enumeration, tail, or
decision fixture; an accepted pooled tie; an assignment count other than 924;
zero packages; fewer than five completed packages in any full post-warm-up
year; nonpositive governed economics; downstream gate failure; or any month,
endpoint, synchronization, side, attempt, risk, package, lifecycle, or
determinism defect. Do not rescue a failure by changing the sample, split,
statistic, boundary, side, carrier, risk, or hold.

Equal target notionals and opposite legs are market-neutral-style construction
only. They do not establish dollar, beta, volatility, factor, market, or
portfolio neutrality. Unchanged Q09 alone owns realized overlap.

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
