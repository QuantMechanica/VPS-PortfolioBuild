# XTI/XNG Monthly LAD Ratio Reversion — Source Approval

Date: 2026-08-28

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

- proposed slug: `xtixng-mlad-rv`
- proposed strategy ID: `VILLAR-KOENKER-BASSETT-XTIXNG-MLAD-RV-2026_S01`
- proposed source ID: `VILLAR-KOENKER-BASSETT-XTIXNG-MLAD-RV-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- proposed companion/traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of each genuine new
  broker month
- signal: fade the strict exact least-absolute-deviation slope sign of
  thirteen synchronized completed monthly oil-minus-gas log ratios

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
2. `strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`,
   SHA-256
   `7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A`.
   It preserves the complete governed reduction of thirteen-observation
   median regression to all 78 pairwise-slope breakpoints, a residual-median
   intercept, total absolute vertical loss, a fixed `1e-12` equality guard,
   and the ordinary median of tied minimizers. Its peer-reviewed method basis
   is Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44–51,
   DOI `10.1016/j.jbankfin.2017.11.010`, using the Koenker–Bassett check-loss
   lineage. Its outright-WTI continuation thesis does not transfer.
3. `strategy-seeds/sources/SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026/source.md`,
   SHA-256
   `CA90E88A038EE778D50361A6BE8BEDBD32D2AB8ED963D388AC8DDDC329BC38D5`.
   This governed packet supplies a fully specified, already reviewed two-leg
   LAD month-end lifecycle precedent. Its precious-metal carrier, economic
   thesis, signal result, and performance do not transfer.

No new public URL or blocked source body is used. The sources do not publish
this exact trading rule, the thirteen-month oil/gas ratio sample, the
contrarian direction, continuous CFDs, equal-target-notional construction,
risk, stops, or lifecycle. Those are transparent QM falsification choices.
No source return, coefficient, significance, density, cost, neutrality,
CFD-equivalence, decorrelation, or portfolio result transfers.

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
   `s[i]=ln(XTI[i])-ln(XNG[i])`, with integer month indexes `x[i]=i`.
4. Enumerate all 78 chronological candidate slopes
   `b(i,j)=(s[j]-s[i])/(j-i)` for `0<=i<j<=12`. For every candidate `b`, sort
   the thirteen residuals `s[i]-b*x[i]`, use residual index six as intercept
   `a`, and compute `L(b)=sum(abs(s[i]-a-b*x[i]))` in chronological order.
5. Retain every candidate whose objective is within exactly `1e-12` of the
   minimum and take the ordinary median of the retained slopes. Require all
   ratios, candidates, residuals, intercepts, objectives, and the final LAD
   slope to be finite.
6. If the LAD slope is positive, SELL XTI and BUY XNG. If it is negative, BUY
   XTI and SELL XNG. Exact zero or invalid state consumes the month flat.
   Signal magnitude never changes size.
7. Open at most one opposite-side equal-target-absolute-USD-notional package
   under one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, cap entry spreads at 1,500 XTI points and
   3,000 XNG points, and cap rounded notional mismatch at 20 percent.
8. Submit XTI first and XNG second. Retain exposure only when exactly one
   correctly directed, stopped position exists in each registered slot;
   otherwise close every owned leg immediately without retry.
9. Close the complete package on the first tick in a later broker month or
   after forty calendar days. Repair any orphaned, duplicated, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package immediately.

There is no Theil–Sen fallback, repeated median, fitted coefficient imported
from a paper, loss normalization, threshold, confidence score, endpoint-
agreement gate, z-score, oscillator, seasonal state, external series, or
prior-result gate. Both news axes, legacy news mode, and Friday close are OFF.
Runtime uses only registered MT5 history, timestamps, logarithms, sorting,
absolute loss, ATR, quotes, contract metadata, position/deal state, and
persistent terminal state.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`: complete government
  and peer-reviewed oil/gas research, including adverse regime evidence, plus
  a complete governed peer-reviewed LAD-method reduction. The exact
  conjunction is untested.
- R2 `PASS`: synchronization, months, ratio orientation, all 78 candidates,
  residual median, absolute objective, equality guard, final median,
  contrarian sides, attempt state, risk, atomicity, and lifecycle are fixed
  before Q02.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories and MT5-native state
  supply every runtime input.
- R4 `PASS`: deterministic arithmetic, sorting, absolute loss, comparisons,
  ATR risk controls, and state only; no trained output, ML, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Pre-Result Density Boundary

Every valid nonzero LAD slope may qualify, producing at most one package per
broker month after thirteen completed monthly endpoints. The pre-result
ceiling is therefore about twelve packages per full post-warm-up year, above
the unchanged five-trades/year Q02 floor. This is only a design-density bound,
not a market probability or performance claim.

## Non-Duplicate Decision

The fail-closed checker first rejected its stale default Wiki root and wrote
`artifacts/qm5_xtixng_mlad_rv_preallocation_dedup_failed_stale_vault_20260828.json`.
It was then rerun against the declared Company Reference Strategy Wiki. The
valid receipt scanned 4,688 registry identities, 1,339 cards, and 45 current
Strategy Wiki nodes and returned `CLEAN`. Evidence is
`artifacts/qm5_xtixng_mlad_rv_preallocation_dedup_20260828.json`, SHA-256
`22D67A6046EE162D757674CBABB994846CC2173E493CA6B375FEEE8D549683FC`.

Manual semantic review fixes the boundary:

- `QM5_41159_wti-lad-tr` applies the estimator to outright WTI, follows its
  sign, and owns one leg. This candidate applies LAD to a synchronized
  oil/gas ratio, fades the sign, and owns an atomic equal-notional basket.
- `QM5_41160_xauxag-mlad-rv` applies the same estimator to a precious-metal
  path and owns only XAU/XAG legs. This candidate owns an economically
  distinct oil/gas path and only energy legs.
- `QM5_41188_xtixng-mrepmedian-rv` computes thirteen pivot-specific slope
  medians followed by an outer median. This candidate profiles an intercept
  for every global candidate and selects slopes by minimum total absolute
  vertical loss.
- On the governed valid vector
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  `-0.002`, while Theil–Sen and repeated median are positive. With the locked
  fade rule, these mechanics can open opposite packages on identical state.
- Pettitt, Mann–Whitney, Cox–Stuart, Spearman, and median-runs XTI/XNG cards
  use change-point, ordinal-win, paired-sign, time-rank, and dichotomized-run
  state functions rather than an absolute-loss median regression.
- `QM5_20237_xtixng-ecm-rv` fits a rolling trend-augmented OLS residual and
  convergence exit; this rule uses thirteen month ends and no residual scale,
  z-score, coefficient bound, or convergence exit.
- `QM5_12578_eia-oilgas-ratio` standardizes a fixed log-price ratio; this rule
  uses only the sign of an exact LAD ratio slope.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback, not a symmetric monthly paired-energy package.

The paired carrier, thirteen synchronized monthly endpoints, log-ratio
orientation, 78 candidates, residual-median intercepts, absolute-loss
objectives, fixed equality rule, contrarian sides, consumed month, equal-
notional aggregate fixed risk, atomic lifecycle, and next-month exit are
jointly load bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_EXACT_LAD_RATIO_SLOPE_REVERSION_BASKET`.

## Kill And Safety Boundary

Q02 must retire below five completed paired packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any month,
endpoint, synchronization, ratio, candidate, residual, intercept, objective,
minimizer, direction, attempt, risk, atomicity, lifecycle, or determinism
defect. No failed result may be rescued by changing the sample, estimator,
carrier, direction, risk, hold, or by adding another gate.

Opposite equal-target-notional legs reduce outright energy direction but do
not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized overlap. This approval excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; terminal control; and component-leg Q02 rows.
Q02 may be enqueued once only after a current strict compile/review PASS and
only below the factory CPU ceiling.
