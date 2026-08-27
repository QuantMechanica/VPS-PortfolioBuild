---
source_id: VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026
title: XTI/XNG thirteen-month repeated-median ratio-slope reversion extraction
publisher: QuantMechanica governed extraction of government, peer-reviewed, and governed method research
source_type: government_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xtixng_monthly_repeated_median_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-SIEGEL-WTI-REPMEDIAN-2026
  - SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-SIEGEL-WTI-REPMEDIAN-2026: 199D39CB5ECAFC7B57F19BA7932DBEF6558529DD68AE00B66AD4531C7FA48E91
  SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026: C96F58F707CA0D622ACF955ABE82E973B60B06F7F872729701C15D3E03B43462
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xtixng-mrepmedian-rv
---

# XTI/XNG Thirteen-Month Repeated-Median Ratio-Slope Reversion Source Packet

## Approved Sources Of Record

The primary relationship record is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It preserves
complete reads of:

- Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between
  Crude Oil and Natural Gas Prices*, U.S. Energy Information Administration,
  43 pages; and
- David J. Ramberg and John E. Parsons (2012), “The Weak Tie Between Natural
  Gas and Oil Prices,” *The Energy Journal* 33(2), 13–35, DOI
  `10.5547/01956574.33.2.2`.

The reports document fuel substitution, co-production, drilling, finance,
and LNG links between oil and gas. They also document large unexplained gas
variation, shifting coefficients, structural instability, and temporary
decoupling. They support testing a state-dependent relationship while
rejecting an immutable or tight ratio.

The statistical-method record is Andrew F. Siegel (1982), “Robust Regression
Using Repeated Medians,” *Biometrika* 69(1), 242–244, DOI
`10.1093/biomet/69.1.242`. The governed packet
`strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md` preserves the
complete official Oxford Academic bibliographic and abstract record and
fixes the exact nested-median arithmetic used here. The paywalled paper body
is not used or represented as completely read.

The two-leg arithmetic, risk, and lifecycle precedent is
`strategy-seeds/sources/SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026/source.md`.
It supplies a fully specified synchronized repeated-median basket contract;
its precious-metal carrier, source thesis, signal, and any result do not
transfer.

All bounded parent records were read completely before the durable OWNER
source approval at
`decisions/2026-08-27_xtixng_monthly_repeated_median_reversion_source_approval.md`,
committed before this extraction at `6c221e724`. No blocked source body,
inferred table, or ungoverned performance claim is used.

## Claim Boundary

The energy sources support a weak, time-varying oil/gas linkage and warn
against a permanently fixed ratio. The Oxford record supplies the
repeated-median robust-regression lineage. Neither source tests a
repeated-median trend on an oil/gas ratio or prescribes a contrarian trading
rule.

The thirteen monthly endpoints, synchronized continuous-CFD mapping,
oil-minus-gas log-ratio orientation, nested medians, contrarian direction,
monthly cadence, equal-target-notional construction, ATR stops, spread caps,
atomic ordering, and lifecycle are pre-result QM translations. No source
alpha, return, coefficient, p-value, significance, density, drawdown, cost,
CFD equivalence, neutrality, decorrelation, or portfolio statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite synchronized completed-month endpoint pairs,
oldest to newest:

```text
L[i] = ln(XTI_close[i]) - ln(XNG_close[i]), i=0..12

for i = 0..12:
  k = 0
  for j = 0..12, j != i:
    lo = min(i,j)
    hi = max(i,j)
    pivot_slope[k] = (L[hi] - L[lo]) / (hi - lo)
    k += 1
  require k == 12
  sorted_pivot = ascending(pivot_slope[0..11])
  pivot_median[i] = (sorted_pivot[5] + sorted_pivot[6]) / 2

require thirteen finite pivot medians
sorted_medians = ascending(pivot_median[0..12])
repeated_median = sorted_medians[6]

repeated_median > 0 => SELL XTI, BUY XNG
repeated_median < 0 => BUY XTI, SELL XNG
otherwise           => FLAT
```

Every unordered endpoint pair contributes the same forward-oriented slope to
the two pivot groups containing its endpoints. There are exactly 156 grouped
slope observations representing 78 unique endpoint pairs twice. There is no
pooled-slope fallback, fitted intercept, loss objective, endpoint agreement,
threshold, confidence score, OLS, z-score, volatility signal, seasonal state,
external series, or prior-result gate. Exact zero or any invalid state
consumes the month flat. Statistic magnitude never changes risk.

## Locked Trading Translation

On the first eligible synchronized D1 tick of a genuine new broker month:

1. Persist the current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. A flat result, rejection, stop,
   restart, or partial package failure may not retry that month.
2. Exclude the current month. In bounded D1 buffers, identify exactly thirteen
   immediately prior consecutive broker months and select the latest exact-
   timestamp-matched completed `XTIUSD.DWX` / `XNGUSD.DWX` close pair in each.
   Require strict chronology, unique consecutive months, positive finite
   prices, and a newest endpoint no more than ten calendar days stale.
3. Apply the exact log-ratio and repeated-median contract above. A zero or
   invalid state consumes the month flat.
4. Fade a nonzero slope sign with opposite equal-target-notional legs. Use one
   aggregate `RISK_FIXED=1000`, split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, reject XTI/XNG entry spreads above
   1,500/3,000 points, and reject more than 20 percent rounded target-notional
   mismatch.
5. Submit XTI first and XNG second. Retain only one valid stopped position per
   registered slot in the required opposite directions. Close all owned legs
   immediately after any submission or final-composition failure.
6. Close the package at the first tick in the next broker month or after
   forty calendar days. Immediately repair an orphan, duplicate, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime reads no
external file, futures chain, API, paper coefficient, optimizer output,
trained artifact, prior backtest result, portfolio state, or live manifest.

## Pre-Result Density Boundary

Every valid nonzero repeated median may qualify, so the rule can produce at
most one package per broker month after thirteen completed monthly endpoints.
Its design-density ceiling is about twelve packages per full post-warm-up
year, above the unchanged five-trades/year Q02 floor. This is not a market
probability or economics claim.

## Non-Duplicate Functional Boundary

The canonical checker returned `CLEAN` across 4,687 registry identities,
1,338 cards, and 45 Strategy Wiki nodes. The receipt is
`artifacts/qm5_xtixng_mrepmedian_rv_preallocation_dedup_20260827.json`,
SHA-256
`AD7CC67FF1F2F7D816624193F7F6B1DB68DAFDF3E26C9EB5FF4F7BCE9081B5AC`.

- XAU/XAG repeated median (`QM5_41164`) owns only precious-metal legs; this
  candidate owns an economically distinct synchronized oil/gas package;
- outright WTI repeated median (`QM5_41158`) follows one WTI price slope with
  one leg; this rule fades one ratio slope with two opposite legs;
- Pettitt (`QM5_41175`) searches change points, Mann–Whitney (`QM5_41178`)
  sums fixed-block wins, Spearman (`QM5_41180`) scores time ranks, and median
  runs (`QM5_41186`) counts dichotomized transitions;
- the oil/gas ECM (`QM5_20237`) fits a rolling trend-augmented OLS residual;
- fixed-ratio z-score (`QM5_12578`) estimates a rolling center and scale; and
- certified `QM5_12567` is a short-horizon long-only XNG oscillator pullback.

The paired energy carrier, thirteen synchronized endpoints, log-ratio
orientation, pivot grouping, twelve forward slopes per pivot, inner indexes
five/six, outer index six, contrarian sides, durable consumed month,
equal-target-notional aggregate fixed risk, atomic lifecycle, and next-month
exit are jointly load bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_SIEGEL_REPEATED_MEDIAN_RATIO_SLOPE_REVERSION_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`: complete government
  and peer-reviewed oil/gas research with adverse regime evidence, plus an
  official peer-reviewed repeated-median bibliographic and abstract record;
  the trading conjunction is untested.
- R2 `PASS`: clock, synchronization, endpoint count, ratio orientation,
  pivot membership, pair bounds, denominator, counts, both median stages,
  direction, attempt, aggregate risk, atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI and XNG D1 histories and MT5-native state supply every input.
- R4 `PASS`: fixed deterministic arithmetic, sorting, comparisons, ATR risk
  controls, and state only, without trained output, banned signal, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Q02 must retire below five completed paired packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any
synchronization, month, ratio, pivot, slope, median, side, attempt, risk,
atomicity, lifecycle, or determinism defect. No failure may be rescued by
changing the carrier, observation count, estimator, direction, risk, hold, or
by adding another gate.

Opposite equal-target-notional legs reduce outright energy direction but do
not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized overlap. This packet supports one Strategy
Card, deterministic allocation, one branch-only V5 build, strict Q01, and one
paced non-live logical-basket Q02 handoff only. It does not authorize a manual
backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, component-leg
Q02 row, terminal control, or decorrelation claim.
