---
source_id: AI-CODEX-XAUXAG-MAD2-RV-20260901
title: XAU/XAG monthly exact-permutation Anderson-Darling distribution-shift reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed relationship and method research plus official exchange and software records
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_xauxag_monthly_anderson_darling_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
method_records:
  - SCHOLZ-STEPHENS-ADK-1987
  - SCIPY-ANDERSON-KSAMP-1.13.1
created: 2026-09-01
created_by: Research+Development
cards_extracted: []
---

# XAU/XAG Exact-Permutation Anderson-Darling Reversion Source Packet

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_xauxag_monthly_anderson_darling_reversion_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one reputable-
source, structural low-frequency sleeve and identifies a market-neutral-style
gold/silver basket as an eligible route. This packet is bounded to one card,
one branch build, strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, the complete governed
   record of Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, the official CME
   gold/silver ratio carrier record;
3. Scholz and Stephens (1987), *Journal of the American Statistical
   Association* 82(399), 918-924, DOI
   `10.1080/01621459.1987.10478517`, complete article and SHA-256 receipt in
   `retrieval_route_scholz_stephens_adk_20260901.json`; and
4. SciPy 1.13.1 official `anderson_ksamp` documentation and pinned source at
   commit `44e4ebaac992fde33f04638b99629d23973cb9b2`, receipt in
   `retrieval_route_scipy_anderson_ksamp_20260901.json`.

No external runtime source, inferred page, trained output, or unpublished
performance result enters the hypothesis.

## Sources Of Record And Adverse Evidence

Schweikert supplies state-dependent and asymmetric gold/silver relationship
evidence. The governed parent also preserves the adverse findings: constant-
vector specifications are not uniformly supported, relevant states are not
known ex ante, and the estimates do not directly produce a forecast. The
relationship motivates a falsifiable relative-value carrier; it does not
transfer a mean-reversion result.

CME defines the gold/silver ratio as gold price divided by silver price per
troy ounce, describes a long/short ratio spread rather than two independent
outrights, and identifies gold's stronger monetary/safe-haven role versus
silver's larger industrial-cycle component. Equal target notionals in the EA
are a QM translation. CME futures liquidity, clearing, offsets, contract
ratios, and execution quality are not claimed for continuous CFDs.

Scholz and Stephens define a nonparametric k-sample rank statistic based on
the weighted squared separation of sample empirical distributions from the
pooled distribution. The `j*(N-j)` denominator gives greater weight to pooled
tails. Their continuous no-tie computational formula depends only on pooled
ranks, and the paper explicitly describes evaluating its finite null
distribution by rank permutations and match-or-exceed frequency.

Pinned SciPy source independently preserves the same continuous right-side
formula and a greater-tail permutation route. The EA imports neither SciPy nor
its asymptotic normalization, critical table, capped interpolation, p-value,
or executable code.

## Source Claim Boundary

The sources jointly motivate one bounded question: after the distribution of
the latest six synchronized monthly gold/silver ratio changes becomes
tail-weightedly different from the prior six, does that relative shift fade
during the next broker month?

No source tests this conjunction. Thirteen synchronized endpoints, adjacent
log-ratio changes, the fixed six/six split, strict no-tie rule, exhaustive 924
assignments, inclusive half-tail activity boundary, rank-sum side, contrarian
package, continuous-CFD mapping, equal-target-notional construction,
fixed-dollar risk, stops, spreads, attempt persistence, atomicity, and
lifecycle are disclosed pre-result QM choices.

No return, alpha, probability, trade density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, statistical
significance, decorrelation, or portfolio statistic transfers from a source.

## Exact Statistical Contract

At a broker-month transition, reconstruct thirteen synchronized, positive,
finite, consecutive completed-month XAU/XAG close pairs. For chronological
endpoints `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old    = r[0..5]
recent = r[6..11]
require all twelve r values pairwise distinct

pool and sort the twelve values ascending
for j=1..11:
    O[j] = number of old labels among pooled ranks 1..j
    R[j] = j - O[j]

A2 = (1/12) * sum over j=1..11 of:
       ( ((12*O[j] - 6*j)^2 / 6)
       + ((12*R[j] - 6*j)^2 / 6) ) / (j*(12-j))

tail_count = 0
assignment_count = 0
for every one of C(12,6)=924 choices of six recent ranks:
    compute A2_perm from the same pooled-rank path
    if A2_perm + 1e-12*max(1,abs(A2)) >= A2:
        tail_count++
    assignment_count++

require assignment_count == 924
require tail_count <= 452
require 2*tail_count <= assignment_count

W_recent = sum of the six pooled ranks tagged recent
SELL XAU / BUY XAG iff W_recent > 39
BUY XAU / SELL XAG iff W_recent < 39
FLAT otherwise
```

The exact tail count is an activity boundary, not a p-value, test size, or
significance claim. Statistic magnitude and tail count never scale risk.

## Pre-Result Density Boundary

Complete enumeration of all 924 strict six-label assignments gives 73 exact
Anderson-Darling statistic values. The largest inclusive tail support not
exceeding one half is 452; the next support is 484. Exactly 452 assignments
pass the half-tail rule. Four have neutral recent rank sum 39, leaving
448/924 qualifying directional states, or `448/77 = 5.8181818` states per
twelve monthly attempts.

This is a market-free combinatorial design prior only. It assumes neither
independent monthly returns nor market rank uniformity and says nothing about
realized data availability, executions, positions, economics, or annual
activity. Q02 must retire the card below five completed packages in any full
post-warm-up year.

## Locked Trading Translation

At the first synchronized executable `XAUUSD.DWX` D1 tick after a genuine
broker-month transition:

1. Normalize and persist current broker `yyyymm` before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month.
2. Exclude current-month prices. Select thirteen immediately prior
   consecutive broker months and the latest exactly timestamp-matched XAU/XAG
   D1 close pair in each. Reject missing, duplicate, unmatched,
   nonchronological, nonpositive, nonfinite, or stale endpoints.
3. Calculate thirteen log ratios and twelve adjacent changes. Reject exact
   change ties. Preserve fixed old/recent membership and compute the complete
   Anderson-Darling pooled-rank path.
4. Enumerate all 924 fixed-size label assignments and consume flat unless the
   observed inclusive tail is at most 452 and the recent rank sum is not 39.
5. Fade a high recent distribution by selling XAU and buying XAG; fade a low
   recent distribution with the opposite package.
6. Open at most one opposite-side equal-target-notional package under one
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
registered native D1 history and timestamps, logarithms, sorting, finite
integer loops, comparisons, broker calendar, quotes, metadata, ATR,
positions, deals, and terminal-persistent attempt state.

## Non-Duplicate Functional Boundary

The fail-closed receipt
`artifacts/qm5_xauxag_mad2_rv_preallocation_dedup_20260901.json` scanned
4,759 registry identities, 1,396 cards, and all 45 Strategy Wiki nodes. It
found no exact identity and conservatively surfaced shared-carrier fuzzy
neighbors.

- `QM5_41187_xauxag-mks-rv` examines twelve monthly ratio *levels* and keeps
  only the largest signed ECDF count gap. This rule examines twelve adjacent
  monthly ratio *changes*, accumulates every squared pooled-rank discrepancy,
  weights the tails, and uses an exhaustive inclusive tail. On a common
  hypothetical no-tie rank path `RROROROROORO`, this rule qualifies at exact
  tail 428 while KS is flat at signed count maxima `(0,2)`. Path
  `RORRROOORORO` reverses the decision: KS qualifies at `(0,3)` while this
  half-tail rule is flat at exact tail 484.
- `QM5_41177_xauxag-mwilcoxon-shift-rv` thresholds only one cross-block rank
  sum on twelve ratio levels. This rule's rank sum supplies direction only
  after the full tail-weighted Anderson-Darling path qualifies, and its state
  object is adjacent ratio changes.
- `QM5_41247_xauxag-mcusum-rv` mean-centers adjacent monthly relative returns
  and uses the maximum cumulative deviation plus change location. This rule
  never mean-centers, searches no time split, and instead compares fixed old
  and recent empirical distributions through all eleven pooled-rank cuts and
  all 924 label assignments.
- `QM5_20263_xauxag-mad-rv` is a 63-D1 rolling median/MAD fresh-cross system
  with convergence exit. The `mad2` slug here means Anderson-Darling
  two-sample; this rule has neither a median/MAD scale nor a daily cross.
- OLS, CADF, quantile, variance-ratio, endpoint, robust-regression, calendar,
  flow, Pettitt, CUSUM, and breakout cards fit or observe different state
  objects, clocks, statistics, or exits.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ADJACENT_RATIO_CHANGE_FIXED_SIX_BY_SIX_CONTINUOUS_ANDERSON_DARLING_FULL_TAIL_WEIGHTED_RANK_PATH_EXACT_924_LABEL_HALF_TAIL_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`: complete governed
  peer-reviewed gold/silver evidence with adverse findings, official exchange
  carrier research, a complete peer-reviewed method paper, pinned official
  SciPy documentation/source, hashes, and explicit translation boundaries.
- R2 `PASS`: clock, synchronization, endpoints, ratio-change orientation,
  fixed blocks, strict ties, formula, every pooled-rank cut, all 924
  assignments, inclusive tolerance, half-tail cap, side, attempt, aggregate
  risk, atomicity, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5-native state provide every runtime
  input; basis, financing, calendar, and legging risks remain.
- R4 `PASS`: deterministic native arithmetic and framework state only; no
  trained output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire on a failed formula/permutation fixture, nondeterministic enumeration,
zero packages, fewer than five completed packages in any full post-warm-up
year, nonpositive governed economics, downstream gate failure, or any month,
endpoint, synchronization, change, tie, rank, statistic, tail, side, attempt,
risk, package, lifecycle, or determinism defect. A failed result may not be
rescued by changing the sample, split, boundary, side, carrier, risk, hold, or
by adding another gate.

Equal target notionals and opposite legs are market-neutral-style
construction only. They do not establish dollar, beta, volatility, factor,
market, or portfolio neutrality. Unchanged Q09 alone owns realized overlap.

Authorized after card G0 and deterministic registries: one branch-only
non-live build, reference tests, strict Q01, one canonical fixed-risk logical-
basket set, and one paced Q02 enqueue below the CPU ceiling. Excluded: manual
backtest, optimization, live/demo/shadow/stress preset, T_Live, AutoTrading,
deploy/live manifest, portfolio-gate change, portfolio admission, correlation
waiver, terminal control, or component-leg Q02 row.

## Revision History

| version | date | change | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | bounded carrier/method synthesis fixed before market testing | source approval | APPROVED_SOURCE |
