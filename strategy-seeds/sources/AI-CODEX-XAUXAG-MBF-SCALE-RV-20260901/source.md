---
source_id: AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901
title: XAU/XAG monthly Brown-Forsythe scale-expansion reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed relationship and method research plus official exchange and method records
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_xauxag_monthly_brown_forsythe_scale_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
method_records:
  - BROWN-FORSYTHE-1974
  - NIST-LEVENE-MEDIAN
  - SCIPY-LEVENE-1.18.0
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41265_xauxag-mbf-scale-rv
---

# XAU/XAG Monthly Brown-Forsythe Scale-Expansion Reversion

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_xauxag_monthly_brown_forsythe_scale_reversion_source_approval.md`.
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
3. NIST/SEMATECH's complete official Levene-test page, including the
   Brown-Forsythe median-centered definition and full statistic; and
4. SciPy 1.18.0 official `scipy.stats.levene` documentation plus the signed-
   tag-pinned implementation at commit
   `54ef5423f2e4376230ec3bfda6912a07a50958e3`.

Brown and Forsythe (1974), *Journal of the American Statistical Association*
69(346), 364-367, DOI `10.1080/01621459.1974.10482955`, supplies the named
peer-reviewed method record. Publisher metadata and abstract were available;
the complete paper body was not accessible in this retrieval, so no complete-
paper read or file hash is claimed. NIST and pinned SciPy independently supply
the complete arithmetic used here. Exact retrieval boundaries and hashes are
stored beside this packet.

No external runtime source, inferred result, trained output, or unpublished
performance number enters the hypothesis.

## Sources Of Record And Adverse Evidence

Schweikert supplies state-dependent and asymmetric gold/silver relationship
evidence. The governed parent preserves adverse findings: constant-vector
specifications are not uniformly supported, relevant states are not known ex
ante, and the estimates do not directly produce a forecast. The relationship
motivates a falsifiable relative-value carrier; it does not transfer a mean-
reversion result.

CME defines the gold/silver ratio as gold price divided by silver price per
troy ounce, describes a long/short intermarket carrier, and distinguishes
gold's monetary/safe-haven sensitivity from silver's larger industrial-cycle
component. Equal target notionals are a QM translation. CME futures clearing,
offsets, contract ratios, and execution quality are not claimed for Darwinex
continuous CFDs.

NIST defines the Levene statistic on within-group absolute deviations. The
Brown-Forsythe median form uses `Z_ij=abs(Y_ij-median_i)`, compares group means
of those deviations through one-way-ANOVA arithmetic, and is recommended by
NIST as a broadly robust choice under non-normality. Pinned SciPy source
independently implements the same median centering, deviation means, weighted
grand mean, and between/within dispersion ratio.

This EA does not use an F critical value or p-value. It uses the exact median-
centered deviations to identify whether the recent fixed block has greater
dispersion than the older block, and computes `W` as a fail-closed diagnostic.
That directional scale-state translation is a disclosed QM choice, not a
source-reported statistical test or trading result.

## Source Claim Boundary

The sources jointly motivate one bounded question: when the dispersion of the
latest six synchronized monthly gold/silver ratio changes expands relative to
the preceding six and their robust centers differ, does the relative center
shift fade during the next broker month?

No source tests this conjunction. Thirteen synchronized endpoints, adjacent
log-ratio changes, the fixed six/six split, even-sample medians, recent-only
scale expansion, median-shift side, contrarian package, continuous-CFD
mapping, equal-target-notional construction, fixed-dollar risk, stops,
spreads, attempt persistence, atomicity, and lifecycle are pre-result QM
choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
hedge ratio, neutrality, CFD equivalence, significance, decorrelation, or
portfolio statistic transfers from a source.

## Exact Statistical Contract

At a broker-month transition, reconstruct thirteen synchronized, positive,
finite, consecutive completed-month XAU/XAG close pairs. For chronological
endpoints `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old    = r[0..5]
recent = r[6..11]

median6(x) = (sort(x)[2] + sort(x)[3]) / 2
m_old      = median6(old)
m_recent   = median6(recent)

z_old[i]    = abs(old[i]    - m_old)
z_recent[i] = abs(recent[i] - m_recent)
zb_old      = sum(z_old) / 6
zb_recent   = sum(z_recent) / 6
zb_all      = (6*zb_old + 6*zb_recent) / 12

ss_between = 6*(zb_old-zb_all)^2 + 6*(zb_recent-zb_all)^2
ss_within  = sum((z_old[i]-zb_old)^2)
           + sum((z_recent[i]-zb_recent)^2)

require ss_within > 1e-18
W = 10 * ss_between / ss_within
require finite W

tol_scale = 1e-12 * max(1, abs(zb_old), abs(zb_recent))
require zb_recent > zb_old + tol_scale

delta = m_recent - m_old
tol_location = 1e-12 * max(1, abs(m_old), abs(m_recent))

SELL XAU / BUY XAG iff delta >  tol_location
BUY XAU / SELL XAG iff delta < -tol_location
FLAT otherwise
```

`10=(N-k)/(k-1)` for `N=12` and `k=2`. There is no F-distribution lookup,
p-value, critical significance boundary, randomized permutation, fitted
window, fallback center, or signal-magnitude sizing. `W` is logged and guarded
but does not scale or qualify risk beyond requiring valid nondegenerate
Brown-Forsythe arithmetic.

## Pre-Result Density Boundary

With equal six-value blocks, swapping the old and recent labels swaps exactly
one strict `zb_recent > zb_old` decision into the qualifying side whenever the
two transformed means differ. That label-swap symmetry gives a market-free
prior of approximately six qualifying scale states per twelve monthly
attempts before median ties, data gates, and execution gates.

This is not a market distribution, trade-count result, or claim of exchangeable
time blocks. Q02 must retire the card below five completed packages in every
full post-warm-up year.

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
3. Calculate thirteen log ratios and twelve adjacent changes. Preserve fixed
   old/recent membership; sort copies only for the two even medians.
4. Compute all twelve absolute deviations, their group means, `ss_between`,
   `ss_within`, and `W`. Consume flat unless recent scale strictly expands
   beyond the relative tolerance and the median shift is nonzero beyond its
   relative tolerance.
5. Fade a higher recent relative-return center by selling XAU and buying XAG;
   fade a lower center with the opposite package.
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
arithmetic, comparisons, broker calendar, quotes, metadata, ATR, positions,
deals, and terminal-persistent attempt state.

## Non-Duplicate Functional Boundary

The fail-closed receipt
`artifacts/qm5_xauxag_mbf_scale_rv_preallocation_dedup_20260901.json` scanned
4,764 registry identities, 1,401 cards, and all 45 Strategy Wiki nodes. It
found no exact identity and conservatively surfaced only the same-carrier
`QM5_41263_xauxag-mkuiper-rv` fuzzy neighbor. Receipt SHA-256:
`9715671276140E339ACBD27B1F855EC12353FF52010448CEE116821FB36CA95F`.

- `QM5_41263` pools and ranks all twelve adjacent changes, adds opposing ECDF
  gaps, enumerates 924 label assignments, and uses recent rank sum for side.
  This rule preserves numeric within-block distance, centers each block on
  its own median, compares mean absolute deviations, performs no label
  enumeration, and uses the two block medians for side.
- `QM5_41260_xauxag-mad2-rv` accumulates the full tail-weighted pooled-rank
  path and gates on an exact 924-assignment tail. This rule has no empirical-
  distribution or exact-tail gate and accepts ties when its denominator and
  strict scale/location comparisons remain valid.
- `QM5_20263_xauxag-mad-rv` is a rolling 63-D1 ratio-level median/MAD fresh
  threshold cross with convergence exit. This rule compares two fixed
  six-month blocks of adjacent changes and always holds to month rollover.
- `QM5_41247_xauxag-mcusum-rv` mean-centers changes and searches a
  chronological cumulative-deviation split. This rule uses a fixed split,
  group-specific medians, absolute deviations, and no searched change point.

Fixed no-tie fixtures establish decision disagreement:

```text
BF-only changes:
[3.75,1.0,-3.5,3.5,2.0,4.5, 2.5,4.75,-2.0,0.5,5.0,0.0]
old/recent zbar = 2.0416666667 / 2.2916666667
old/recent median = 2.75 / 1.50; W = 0.0622837370
=> Brown-Forsythe BUY XAU / SELL XAG; AD and Kuiper neutral at rank sum 39.

Rank-only changes:
[4.75,-3.5,3.75,-3.75,-2.5,-1.0, 2.0,-2.0,0.75,-0.75,-0.5,6.0]
old/recent zbar = 2.875 / 2.0
=> Brown-Forsythe flat; AD and Kuiper SELL XAU / BUY XAG.

Side-disagreement changes:
[-2.0,0.75,-3.25,0.5,-4.75,0.25, 3.0,1.5,-4.5,-3.0,1.0,-3.5]
old/recent zbar = 1.9166666667 / 2.75
old/recent median = -0.875 / -1.0
=> Brown-Forsythe BUY XAU / SELL XAG; AD and Kuiper take the opposite side.
```

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ADJACENT_RATIO_CHANGE_FIXED_SIX_BY_SIX_BROWN_FORSYTHE_MEDIAN_CENTERED_RECENT_SCALE_EXPANSION_MEDIAN_SHIFT_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`: complete governed
  peer-reviewed gold/silver evidence with adverse findings, official exchange
  carrier research, a named peer-reviewed Brown-Forsythe method record with
  explicit body-access boundary, complete official NIST formula, signed-tag-
  pinned official SciPy documentation/source, hashes, and explicit
  translation limits.
- R2 `PASS`: clock, synchronization, endpoints, change orientation, fixed
  blocks, medians, deviations, group means, between/within sums, denominator,
  statistic, tolerances, side, attempt, aggregate risk, atomicity, and
  lifecycle are deterministic and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5-native state provide every runtime
  input; basis, financing, calendar, and legging risks remain.
- R4 `PASS`: deterministic native arithmetic and framework state only; no
  trained output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire on a failed formula fixture, zero packages, fewer than five completed
packages in any full post-warm-up year, nonpositive governed economics,
downstream gate failure, or any month, endpoint, synchronization, change,
median, deviation, statistic, side, attempt, risk, package, lifecycle, or
determinism defect. A failed result may not be rescued by changing the
sample, split, center, scale comparison, side, carrier, risk, hold, or by
adding a gate.

Equal target notionals and opposite legs are market-neutral-style
construction only. They do not establish dollar, beta, volatility, factor,
market, or portfolio neutrality. Unchanged Q09 alone owns realized overlap.

Authorized after card G0 and deterministic registries: one branch-only
non-live build, reference tests, strict Q01, one canonical fixed-risk logical-
basket set plus component validation sets, and one paced Q02 enqueue below the
CPU ceiling. Excluded: manual backtest, optimization, live/demo/shadow/stress
preset, `T_Live`, AutoTrading, deploy/live manifest, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or component-leg
Q02 row.

## Revision History

| version | date | change | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | bounded carrier/method synthesis fixed before market testing | source approval | APPROVED_SOURCE |
