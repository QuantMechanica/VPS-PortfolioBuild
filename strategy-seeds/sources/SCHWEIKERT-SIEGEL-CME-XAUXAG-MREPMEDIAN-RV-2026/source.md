---
source_id: SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026
title: XAU/XAG thirteen-month repeated-median ratio-slope reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and governed method research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_xauxag_monthly_repeated_median_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - MOP-SIEGEL-WTI-REPMEDIAN-2026
  - SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  MOP-SIEGEL-WTI-REPMEDIAN-2026: 199D39CB5ECAFC7B57F19BA7932DBEF6558529DD68AE00B66AD4531C7FA48E91
  SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026: 69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - xauxag-mrepmedian-rv
---

# XAU/XAG Thirteen-Month Repeated-Median Ratio-Slope Reversion Source Packet

## Approved Sources Of Record

The primary relationship source is Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. The complete 32-page author preprint is
preserved in the governed packet
`strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`.

The statistical-method record is Andrew F. Siegel (1982), "Robust Regression
Using Repeated Medians," *Biometrika* 69(1), 242-244, DOI
`10.1093/biomet/69.1.242`. The governed packet
`strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md` preserves the
complete official Oxford Academic bibliographic and abstract record and fixes
the exact nested-median arithmetic used here. The paywalled paper body is not
used or represented as completely read.

The carrier, synchronization, risk, and lifecycle precedent is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`.
It preserves official CME Group gold/silver ratio-spread lineage and the
governed two-leg XAU/XAG month-end contract. Its pooled median-of-78-slopes
signal does not transfer.

All three bounded parent records were read completely before the durable
OWNER source approval at
`decisions/2026-08-26_xauxag_monthly_repeated_median_reversion_source_approval.md`.
No new online route, blocked content, inferred source table, or ungoverned
performance claim is used.

## Source Findings Used

Schweikert supports testing a related but state-dependent gold/silver price
relation and supplies adverse evidence against assuming a safe constant-vector
arbitrage. CME supports the intermarket ratio carrier and identifies shared
precious-metal/USD drivers alongside distinct monetary, safe-haven,
industrial, and business-cycle exposures. Siegel supplies nested-median robust
regression lineage.

These findings support a falsifiable relative-value test. They do not establish
that a repeated-median slope of the gold/silver ratio will reverse, that it is
superior to another robust statistic, or that equal-notional CFD legs are
market neutral. The exact sample, calendar, synchronization, ratio orientation,
nested medians, contrarian direction, continuous-CFD mapping, risk, stops,
spread caps, attempt state, atomicity, and lifecycle are transparent QM
choices. No source return, alpha, probability, trade density, Sharpe ratio,
drawdown, cost, hedge ratio, neutrality, robustness improvement, CFD
equivalence, or portfolio-correlation statistic transfers.

## Bounded QM Mechanization

On the first synchronized executable D1 tick of a new broker month, exclude
the current month and reconstruct exactly thirteen consecutive completed
broker months ending with the immediately prior month. Retain the latest
exactly timestamp-matched `XAUUSD.DWX` and `XAGUSD.DWX` close pair in every
month. Missing or duplicate months, unmatched timestamps, nonchronological
pairs, nonpositive closes, and stale endpoints are invalid.

For chronological pairs `i=0..12`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])

for i = 0..12:
  k = 0
  for j = 0..12, j != i:
    lo = min(i,j)
    hi = max(i,j)
    pivot_slope[k] = (s[hi] - s[lo]) / (hi - lo)
    k += 1
  require k == 12
  sorted_pivot = ascending(pivot_slope[0..11])
  pivot_median[i] = (sorted_pivot[5] + sorted_pivot[6]) / 2

require thirteen finite pivot medians
sorted_medians = ascending(pivot_median[0..12])
repeated_median = sorted_medians[6]

repeated_median > 0 => SELL XAU, BUY XAG
repeated_median < 0 => BUY XAU, SELL XAG
otherwise           => FLAT
```

Each unordered endpoint pair contributes the same forward-oriented slope to
the two pivot groups containing its endpoints. There are exactly 156 grouped
slope observations representing 78 unique endpoint pairs twice. There is no
pooling fallback, fitted intercept, loss objective, endpoint agreement,
threshold, confidence score, OLS, z-score, volatility signal, seasonal state,
external series, or previous pipeline result. Exact zero or any invalid state
consumes the month flat, and statistic magnitude never changes risk.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, and an entry
   attempt no later than 180 elapsed minutes after the raw current host D1 bar
   open in a genuine new broker month.
2. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order checks. A flat result,
   invalid state, reject, stop, partial package, or restart never retries the
   month.
3. From bounded native D1 buffers, select exactly the latest synchronized pair
   in each of the immediately prior thirteen consecutive broker months. The
   newest pair must be no more than ten calendar days stale.
4. Reverse the selected pairs into strict chronological order; compute all
   thirteen finite log ratios, twelve forward slopes in each of thirteen
   pivot groups, thirteen inner medians, and one outer median. No alternate
   statistic or agreement gate is allowed.
5. Fade the strict repeated-median sign with opposite legs.
6. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   aggregate stop-risk budget equally, size each leg against its frozen
   `3.5*ATR(20,D1)` broker hard stop, attach no target, cap entry spread at
   1,500 XAU points and 500 XAG points, and require realized absolute-notional
   mismatch no greater than 20%.
7. Submit XAU first and XAG second. Retain the package only when exactly one
   correctly directed, correctly registered, stop-protected position exists
   in each slot. Flatten every owned leg immediately after a second-leg or
   final-package validation failure.
8. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF for the monthly
hold. Runtime uses only registered MT5 histories, timestamps, calendar,
quotes, symbol metadata, ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,663 registry identities, 1,314
card files, and 45 Strategy Wiki nodes and returned no exact or fuzzy match.
The successful receipt is
`artifacts/qm5_xauxag_mrepmedian_rv_preallocation_dedup_20260826.json`,
SHA-256
`D831A578286D639AFD34C8BC6AA02A9D6FEF93E3B5AD14E1DBC346691D8CB28F`.

Manual semantic and functional review fixes a new mechanic:

- `QM5_41157_xauxag-mtheilsen-rv` pools all 78 unique forward slopes and
  takes one global even-sample median. This rule takes thirteen pivot-specific
  medians and then their outer median.
- `QM5_41160_xauxag-mlad-rv` profiles an intercept for candidate slopes and
  minimizes vertical absolute loss. This rule has no intercept or objective.
- For log-ratio levels
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, existing
  Theil-Sen is `+0.00155555555555556`, existing LAD is `+0.00375`, and this
  repeated median is `-0.0045`. With the common fade direction, this rule
  opens the opposite basket from both existing estimators.
- `QM5_41158_wti-repmedian-tr` applies the same estimator to outright WTI,
  follows its sign, and owns one energy leg. This rule applies it to a
  synchronized gold/silver relative path, fades it, and owns an atomic
  equal-notional basket.
- `QM5_13205_xau-xag-qc` estimates conditional cross-sectional regressions
  over 504 D1 pairs and trades envelope tails. This rule estimates no alpha,
  beta, envelope, residual scale, or threshold.
- Fixed z-score, OLS, CADF, MAD, daily-return pseudomedian, path, sign, flow,
  and calendar cards operate on other state objects or aggregations.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback and shares neither carrier nor mechanic.

The paired carrier, thirteen synchronized month-end observations, log-ratio
orientation, pivot grouping, twelve forward slopes per pivot, inner indexes
5/6, outer index 6, contrarian sides, durable consumed month, equal-notional
aggregate fixed risk, atomic lifecycle, and next-month exit are jointly
load-bearing. Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`. Named-author peer-reviewed
  gold/silver evidence with DOI and complete author-preprint read, official
  exchange carrier research, and named-author peer-reviewed repeated-median
  lineage with DOI. The conjunction is explicitly untested.
- R2: `PASS`. Clock, synchronization, month selection, ratio orientation,
  pivot membership, pair bounds, denominator, counts, both median stages,
  direction, attempt, aggregate risk, stops, atomicity, and lifecycle are
  fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs.
- R4: `PASS`. Deterministic timestamps, logarithms, finite arithmetic,
  sorting, comparisons, ATR risk controls, and execution state only; no
  trained output, prohibited signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

## Claim And Kill Boundary

Every valid nonzero repeated median may qualify, giving a pre-result density
prior near twelve packages per year after a thirteen-month warm-up. This is
not market evidence. Q02 must retire below five completed packages in any
full post-warm-up year, at zero trades, with nonpositive governed economics,
or on any synchronization, month, ratio, pivot, slope, median, side, attempt,
risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized book correlation. No failure may be rescued
by changing the carrier, observation count, estimator, direction, risk, hold,
or by adding endpoint agreement, scale, event, seasonal, volatility, external,
or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, deterministic allocation, one branch-
only V5 build, strict compile/Q01, and one paced non-live logical-basket Q02
handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or decorrelation claim.
