# XTI/XNG Monthly Repeated-Median Ratio Reversion — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. It requests one genuinely different,
structural, low-frequency commodity or energy edge, expressly permits a
market-neutral basket, requires reputable-source criteria and `RISK_FIXED`
backtests, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xtixng-mrepmedian-rv`
- proposed strategy ID: `VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026_S01`
- proposed source ID: `VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- proposed companion/traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of each genuine new
  broker month
- signal: fade the strict repeated-median slope sign of thirteen synchronized
  completed monthly oil-minus-gas log ratios

The canonical allocator owns the EA ID. This record neither predicts nor
reserves an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It records complete reads of Jose A. Villar and Frederick L. Joutz (2006),
   U.S. EIA, *The Relationship Between Crude Oil and Natural Gas Prices*, and
   David J. Ramberg and John E. Parsons (2012), *The Energy Journal* 33(2),
   13–35, DOI `10.5547/01956574.33.2.2`. The sources document physical and
   economic oil/gas links, error correction, large unexplained gas variation,
   and regime instability. They reject a permanently tight or fixed tie.
2. `strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md`, SHA-256
   `199D39CB5ECAFC7B57F19BA7932DBEF6558529DD68AE00B66AD4531C7FA48E91`.
   It preserves the complete official bibliographic and abstract record for
   Andrew F. Siegel (1982), “Robust Regression Using Repeated Medians,”
   *Biometrika* 69(1), 242–244, DOI `10.1093/biomet/69.1.242`, and fixes the
   exact nested-median arithmetic used here. The paywalled paper body is not
   used or represented as completely read.
3. `strategy-seeds/sources/SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026/source.md`,
   SHA-256
   `C96F58F707CA0D622ACF955ABE82E973B60B06F7F872729701C15D3E03B43462`.
   This governed source packet supplies a fully specified, already reviewed
   two-leg repeated-median month-end lifecycle precedent. Its precious-metal
   carrier, evidence, signal result, and performance do not transfer.

No new public URL or blocked source body is used. The sources do not publish
this trading rule, the thirteen-month oil/gas ratio sample, the contrarian
direction, continuous CFDs, equal-target-notional construction, risk, stops,
or lifecycle. Those are transparent QM falsification choices. No source
return, coefficient, significance, density, cost, neutrality, CFD-equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first synchronized executable D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate. One month
   may produce at most one consumed attempt.
2. Exclude the current month. Reconstruct the latest synchronized D1 close
   pair from each of exactly thirteen immediately prior consecutive completed
   broker months. Require one common latest timestamp per month, strict
   chronology, no missing or duplicate month, positive finite closes, and a
   newest endpoint no more than ten calendar days stale.
3. Form the thirteen chronological oil-minus-gas log ratios
   `L[i]=ln(XTI[i])-ln(XNG[i])`, for `i=0..12`.
4. For every pivot `i`, calculate the twelve forward-oriented slopes joining
   it to every other point:

   `slope(i,j)=(L[max(i,j)]-L[min(i,j)])/(max(i,j)-min(i,j))`.

   Sort each pivot's twelve slopes and define its inner median as the mean of
   sorted indexes five and six. Sort all thirteen finite inner medians and
   define the repeated median as index six. This requires 156 grouped slope
   observations representing 78 unique endpoint pairs twice.
5. If the repeated median is positive, SELL XTI and BUY XNG. If it is
   negative, BUY XTI and SELL XNG. Exact zero or any invalid state consumes
   the month flat. Signal magnitude never changes size.
6. Open at most one opposite-side equal-target-absolute-USD-notional package
   under one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, cap entry spreads at 1,500 XTI points and
   3,000 XNG points, and cap rounded notional mismatch at 20 percent.
7. Submit XTI first and XNG second. Retain exposure only when exactly one
   correctly directed, stopped position exists in each registered slot;
   otherwise close every owned leg immediately without retry.
8. Close the complete package on the first tick in a later broker month or
   after forty calendar days. Repair any orphaned, duplicated, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package immediately.

There is no pooled Theil–Sen fallback, fitted intercept, loss objective,
threshold, confidence score, endpoint-agreement gate, z-score, oscillator,
seasonal state, external series, or prior-result gate. Both news axes, legacy
news mode, and Friday close are OFF. Runtime uses only registered MT5 history,
timestamps, logarithms, sorting, ATR, quotes, contract metadata, position/deal
state, and persistent terminal state.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`: complete government
  and peer-reviewed oil/gas research, including adverse regime evidence, plus
  an official peer-reviewed repeated-median bibliographic and abstract
  record. The exact conjunction is untested.
- R2 `PASS`: synchronization, months, ratio orientation, pivot membership,
  slope direction, both median stages, contrarian sides, attempt state, risk,
  atomicity, and lifecycle are fixed before Q02.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories and MT5-native state
  supply every runtime input.
- R4 `PASS`: deterministic arithmetic, sorting, comparisons, ATR risk
  controls, and state only; no trained output, ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Pre-Result Density Boundary

Every valid nonzero repeated median may qualify, producing at most one package
per broker month after thirteen completed monthly endpoints. The pre-result
ceiling is therefore about twelve packages per full post-warm-up year, above
the unchanged five-trades/year Q02 floor. This is only a design-density bound,
not a market probability or performance claim.

## Non-Duplicate Decision

The fail-closed checker scanned 4,687 registry identities, 1,338 cards, and
the actual 45-node Company Reference Strategy Wiki. It returned no exact or
fuzzy match. Evidence is
`artifacts/qm5_xtixng_mrepmedian_rv_preallocation_dedup_20260827.json`,
SHA-256
`AD7CC67FF1F2F7D816624193F7F6B1DB68DAFDF3E26C9EB5FF4F7BCE9081B5AC`.

Manual semantic review fixes the boundary:

- `QM5_41164_xauxag-mrepmedian-rv` applies the same estimator to a
  gold/silver relative path and owns only metal legs; this candidate applies
  it to the economically distinct oil/gas relation and owns only energy legs.
- `QM5_41158_wti-repmedian-tr` applies the estimator to outright WTI and
  follows its sign with one leg; this candidate applies it to a synchronized
  oil/gas ratio and fades the sign with two opposite legs.
- `QM5_41175_xtixng-mpettitt-rv` searches every possible change point;
  `QM5_41178_xtixng-mwilcoxon-rv` sums fixed-block ordinal wins;
  `QM5_41180_xtixng-mspearman-rv` ranks time displacement; and
  `QM5_41186_xtixng-median-runs-rv` counts median-side transitions. None
  computes thirteen pivot-specific slope medians followed by an outer median.
- `QM5_20237_xtixng-ecm-rv` fits a rolling trend-augmented OLS residual and
  convergence exit; this rule fits no coefficient, intercept, residual scale,
  or half-life.
- `QM5_12578_eia-oilgas-ratio` standardizes a fixed log-price ratio; this rule
  uses only the sign of a nested-median ratio slope.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback, not a symmetric monthly paired-energy package.

The paired carrier, thirteen synchronized monthly endpoints, log-ratio
orientation, pivot grouping, twelve forward slopes per pivot, inner indexes
five/six, outer index six, contrarian sides, consumed month, equal-notional
aggregate fixed risk, atomic lifecycle, and next-month exit are jointly load
bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_SIEGEL_REPEATED_MEDIAN_RATIO_SLOPE_REVERSION_BASKET`.

## Kill And Safety Boundary

Q02 must retire below five completed paired packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any month,
endpoint, synchronization, ratio, pivot, slope, median, direction, attempt,
risk, atomicity, lifecycle, or determinism defect. No failed result may be
rescued by changing the sample, estimator, carrier, direction, risk, hold, or
by adding another gate.

Opposite equal-target-notional legs reduce outright energy direction but do
not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized overlap. This approval excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; terminal control; and component-leg Q02 rows.
Q02 may be enqueued once only after a current strict compile/review PASS and
only below the factory CPU ceiling.
