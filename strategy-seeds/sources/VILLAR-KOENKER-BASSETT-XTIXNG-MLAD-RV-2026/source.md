---
source_id: VILLAR-KOENKER-BASSETT-XTIXNG-MLAD-RV-2026
title: XTI/XNG thirteen-month least-absolute-deviation ratio-slope reversion extraction
publisher: QuantMechanica governed extraction of government, peer-reviewed, and governed method research
source_type: government_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-28_xtixng_monthly_lad_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-KOENKER-BASSETT-WTI-LAD-2026
  - SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-KOENKER-BASSETT-WTI-LAD-2026: 7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A
  SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026: CA90E88A038EE778D50361A6BE8BEDBD32D2AB8ED963D388AC8DDDC329BC38D5
created: 2026-08-28
created_by: Research+Development
cards_extracted:
  - xtixng-mlad-rv
---

# XTI/XNG Thirteen-Month LAD Ratio-Slope Reversion Source Packet

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

The exact median-regression arithmetic record is
`strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`, SHA-256
`7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A`.
Its peer-reviewed method basis includes Karsten Schweikert (2018), “Are gold
and silver cointegrated? New evidence from quantile cointegrating
regressions,” *Journal of Banking & Finance* 88, 44–51, DOI
`10.1016/j.jbankfin.2017.11.010`. At the median quantile, symmetric
Koenker–Bassett check loss is one half of total absolute vertical error; the
constant factor does not change its minimizer. The packet fixes an exact
finite solver for thirteen observations. Its outright-WTI trading carrier,
continuation direction, and performance do not transfer.

The two-leg arithmetic, risk, and lifecycle precedent is
`strategy-seeds/sources/SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026/source.md`,
SHA-256
`CA90E88A038EE778D50361A6BE8BEDBD32D2AB8ED963D388AC8DDDC329BC38D5`.
It supplies a fully specified synchronized monthly LAD basket contract; its
precious-metal carrier, source thesis, signal, and any result do not
transfer.

All bounded parent records were read completely before the durable OWNER
source approval at
`decisions/2026-08-28_xtixng_monthly_lad_reversion_source_approval.md`, commit
`f96fc89ed`. No blocked source body, inferred table, or ungoverned
performance claim is used.

## Claim Boundary

The energy sources support a weak, time-varying oil/gas linkage and warn
against a permanently fixed ratio. The method record supplies exact
least-absolute-deviation median-regression arithmetic. Neither source tests
an LAD trend on an oil/gas ratio or prescribes a contrarian trading rule.

The thirteen monthly endpoints, synchronized continuous-CFD mapping,
oil-minus-gas log-ratio orientation, absolute-loss minimization, contrarian
direction, monthly cadence, equal-target-notional construction, ATR stops,
spread caps, atomic ordering, and lifecycle are pre-result QM translations.
No source alpha, return, coefficient, p-value, significance, density,
drawdown, cost, CFD equivalence, neutrality, decorrelation, or portfolio
statistic transfers.

## Exact LAD Contract

For thirteen positive, finite synchronized completed-month endpoint pairs,
oldest to newest, define `s[i]` and `x[i]` as:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i]), i=0..12
x[i] = i

k = 0
for i = 0..11:
  for j = i+1..12:
    candidate[k] = (s[j] - s[i]) / (j - i)
    k += 1
require k == 78

for each candidate b:
  residual[i] = s[i] - b*x[i], i=0..12
  intercept = ascending(residual)[6]
  objective(b) = sum(i=0..12) abs(s[i] - intercept - b*x[i])

minimum = min(objective(candidate[0..77]))
retain every b where abs(objective(b) - minimum) <= 1e-12
lad_slope = ordinary median of ascending retained slopes

lad_slope > 0 => SELL XTI, BUY XNG
lad_slope < 0 => BUY XTI, SELL XNG
otherwise     => FLAT
```

Candidate enumeration is lexicographic in `(i,j)`. Every denominator is the
positive integer month-index distance. For every candidate the thirteen
residuals are evaluated, sorted for intercept index six, then recomputed and
summed in chronological index order. All 78 candidates, 78 intercepts, 78
objectives, retained minimizers, and the final median must be finite. The
`1e-12` guard is a locked numeric equality convention, not a signal or
performance threshold.

There is no iterative optimizer, fitted bound, random start, Theil–Sen
fallback, repeated median, OLS, z-score, loss normalization, endpoint-
agreement gate, volatility signal, seasonal state, external series, or
prior-result gate. Exact zero or any invalid state consumes the month flat.
Statistic magnitude never changes risk.

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
3. Apply the exact log-ratio and LAD contract above. A zero or invalid state
   consumes the month flat.
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

Every valid nonzero LAD slope may qualify, so the rule can produce at most
one package per broker month after thirteen completed monthly endpoints. Its
design-density ceiling is about twelve packages per full post-warm-up year,
above the unchanged five-trades/year Q02 floor. This is not a market
probability or economics claim.

## Non-Duplicate Functional Boundary

The canonical checker first failed closed on its stale default Wiki root and
then returned `CLEAN` against the declared Company Reference root across
4,688 registry identities, 1,339 cards, and 45 Strategy Wiki nodes. The valid
receipt is
`artifacts/qm5_xtixng_mlad_rv_preallocation_dedup_20260828.json`, SHA-256
`22D67A6046EE162D757674CBABB994846CC2173E493CA6B375FEEE8D549683FC`.

- XAU/XAG LAD (`QM5_41160`) owns only precious-metal legs; this candidate owns
  an economically distinct synchronized oil/gas package;
- outright WTI LAD (`QM5_41159`) follows one WTI price slope with one leg;
  this rule fades one ratio slope with two opposite legs;
- XTI/XNG repeated median (`QM5_41188`) takes thirteen pivot-specific slope
  medians and an outer median; this rule profiles one median intercept per
  global candidate and minimizes total absolute vertical loss;
- the governed vector
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]` yields LAD
  `-0.002` while Theil–Sen and repeated median are positive, so the locked
  fade rules can open opposite packages on identical valid state;
- Pettitt (`QM5_41175`), Mann–Whitney (`QM5_41178`), Cox–Stuart (`QM5_41179`),
  Spearman (`QM5_41180`), and median-runs (`QM5_41186`) use change-point,
  ordinal-win, paired-sign, time-rank, and dichotomized-transition state;
- the oil/gas ECM (`QM5_20237`) fits a rolling trend-augmented OLS residual
  and convergence exit;
- fixed-ratio z-score (`QM5_12578`) estimates a rolling center and scale; and
- certified `QM5_12567` is a short-horizon long-only XNG oscillator pullback.

The paired energy carrier, thirteen synchronized endpoints, log-ratio
orientation, all 78 candidates, residual-median intercepts, absolute-loss
objectives, equality guard, contrarian sides, durable consumed month, equal-
target-notional aggregate fixed risk, atomic lifecycle, and next-month exit
are jointly load bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_EXACT_LAD_RATIO_SLOPE_REVERSION_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`: complete government
  and peer-reviewed oil/gas research with adverse regime evidence, plus a
  complete governed peer-reviewed median-regression reduction; the trading
  conjunction is untested.
- R2 `PASS`: clock, synchronization, endpoint count, ratio orientation,
  candidate enumeration, residual median, chronological objective, equality
  guard, final median, direction, attempt, aggregate risk, atomicity, and
  lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI and XNG D1 histories and MT5-native state supply every input.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, absolute loss,
  comparisons, ATR risk controls, and state only, without trained output,
  banned signal, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Q02 must retire below five completed paired packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any
synchronization, month, ratio, candidate, residual, intercept, objective,
minimizer, side, attempt, risk, atomicity, lifecycle, or determinism defect.
No result may be rescued by changing the sample, estimator, direction,
carrier, stop, spread cap, hold, or by adding another state filter.

Opposite equal-target-notional legs reduce some common outright-energy
direction but do not prove dollar, beta, volatility, factor, market, or
portfolio neutrality. Unchanged Q09 alone owns realized overlap. This packet
does not authorize a manual backtest, live artifact, `T_Live`, AutoTrading,
deploy manifest, portfolio-gate change, portfolio admission, correlation
waiver, terminal control, or component-leg Q02 rows.
