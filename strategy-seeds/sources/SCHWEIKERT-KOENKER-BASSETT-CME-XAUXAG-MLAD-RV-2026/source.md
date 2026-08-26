---
source_id: SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026
title: XAU/XAG thirteen-month least-absolute-deviation ratio-slope reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and governed method research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_xauxag_monthly_lad_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - MOP-KOENKER-BASSETT-WTI-LAD-2026
  - SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  MOP-KOENKER-BASSETT-WTI-LAD-2026: 7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A
  SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026: 69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - xauxag-mlad-rv
---

# XAU/XAG Thirteen-Month LAD Ratio-Slope Reversion Source Packet

## Approved Sources Of Record

The primary relationship source is Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`.

The governed packet `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`,
SHA-256
`7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`,
records a complete read of the 32-page author preprint. It preserves the
economic motivation, model, linear and quantile cointegration estimators,
monthly and daily spot tests, futures tests, appendix, conclusion,
references, and adverse evidence. Equation 10 estimates quantile-specific
intercepts and slopes by minimizing Koenker-Bassett asymmetric check loss.
At the median quantile, the symmetric check-loss objective is one half of
total absolute vertical error, so the factor one half does not alter its
minimizer.

The exact median-regression arithmetic precedent is
`strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`, SHA-256
`7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A`.
It fixes a finite exact reduction for thirteen observations: all 78
pairwise-slope breakpoints, the residual-median profiled intercept, the
thirteen-term absolute-loss objective, a fixed `1e-12` loss-equality guard,
and the ordinary median of tied minimizing slopes. Its outright WTI carrier,
momentum source, continuation direction, and one-leg execution do not
transfer.

The governed carrier and lifecycle precedent is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
SHA-256
`69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA`.
It preserves the peer-reviewed gold/silver relationship and official CME
ratio-spread lineage, exact synchronized completed-month endpoint selection,
gold-minus-silver log-ratio orientation, equal-notional aggregate fixed-risk
package, order atomicity, and next-month lifecycle. Its global median of 78
pairwise slopes does not transfer.

All three bounded records were read completely before the durable OWNER
source approval at
`decisions/2026-08-26_xauxag_monthly_lad_reversion_source_approval.md`, commit
`c0e49c012`. Two new public URL leads were classified
`DEFERRED:SOURCE_POLICY` by the required source reader and are not used here.
No blocked source body, inferred table value, or ungoverned performance claim
is part of this extraction.

## Source Findings Used

Schweikert models gold and silver with quantile-varying intercepts and slopes
and finds a state-dependent, asymmetric relation. The response is generally
stronger in upper price quantiles and when both metals act as safe havens.
This supports testing a relative-price relation but not a universal constant
equilibrium.

The paper is adverse to naive statistical arbitrage. Important
specifications reject constant-vector linear cointegration, some daily upper
quantiles reject quantile cointegration, the state is not known ex ante, and
the estimates are not directly usable as forecasts. Earlier literature in
the paper also failed to establish a profitable ex-ante intercommodity
spread rule. Those limitations remain binding.

The governed CME lineage supports the gold/silver ratio as an intermarket
spread and records distinct monetary, safe-haven, industrial, and business-
cycle drivers for the two legs. It does not support a contrarian signal,
specific horizon, or expected profit.

The LAD packet supplies exact deterministic median-regression arithmetic. It
does not support applying that functional to gold/silver, fading its slope,
or expecting reversion. Conversely, the metals sources do not specify
thirteen endpoints, 78 slope candidates, a profiled median intercept, or an
absolute-loss minimizer.

The exact conjunction below is a transparent QM translation. No source
return, alpha, probability, density, Sharpe ratio, drawdown, cost estimate,
hedge ratio, neutrality, continuous-CFD equivalence, estimator superiority,
or book-correlation statistic transfers.

## Exact LAD Reduction

For thirteen chronological synchronized month-end log ratios
`s[i]=ln(XAU_close[i])-ln(XAG_close[i])` and month indexes `x[i]=i`, define

```text
Q(a,b) = sum(i=0..12) abs(s[i] - a - b*x[i]).
```

For a fixed slope `b`, a minimizing intercept is the median of the thirteen
residuals `s[i]-b*x[i]`, namely ascending residual index 6. The profiled
objective is convex and piecewise linear in `b`; residual-order crossings
occur at the 78 slopes `(s[j]-s[i])/(j-i)` for every `i<j`. Therefore at
least one optimum is attained at a candidate breakpoint. The mechanization
evaluates every candidate and does not rely on an iterative optimizer,
convergence tolerance, fitted bound, random start, or subsample.

Candidate enumeration is lexicographic in `(i,j)`. For each candidate, the
thirteen residuals are calculated and summed in chronological index order
after selecting the median intercept. Every value must be finite. Every
candidate whose objective lies within exactly `1e-12` of the minimum is
retained; the ordinary median of retained slopes is `lad_slope`. The guard is
a fixed floating-point tie convention and is not a signal-strength or
performance parameter.

## Bounded QM Mechanization

At the first synchronized executable D1 tick in a genuine new broker month,
exclude the current month and reconstruct exactly thirteen consecutive
completed broker months ending with the immediately prior month. Select the
latest exactly timestamp-matched `XAUUSD.DWX` and `XAGUSD.DWX` close pair in
each month and reverse the selected pairs into strict chronological order.

Compute all thirteen gold-minus-silver log ratios, all 78 forward pairwise
slopes, the 78 residual-median intercepts, and the 78 absolute-loss
objectives. Take the median of the slopes tied at the minimum objective under
the fixed guard. Fade a positive slope with SELL XAU / BUY XAG. Fade a
negative slope with BUY XAU / SELL XAG. Exact zero or invalid arithmetic
consumes the month flat. The slope magnitude never changes risk.

The approved execution contract is:

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, and an
   entry attempt no later than 180 elapsed minutes after the raw current host
   D1 bar open in a genuine new broker month.
2. Persist the current broker `yyyymm` as consumed before every fallible
   gate. Never retry after a flat state, invalid history, reject, partial
   package, stop, or restart.
3. Require thirteen immediately prior consecutive month keys, exact
   timestamp matches, positive finite closes, chronological pairs, and a
   newest endpoint no more than ten calendar days stale.
4. Require exactly 78 finite candidate slopes, exactly 78 thirteen-residual
   profiles, and finite nonnegative objectives. Apply the locked residual
   median, chronological loss order, `1e-12` equality guard, final ordinary
   median, strict sign, and contrarian side mapping.
5. Open at most one equal-target-absolute-USD-notional package under
   aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split aggregate stop risk equally and size each leg
   against its frozen `3.5*ATR(20,D1)` hard stop. Attach no target. Cap
   spread at 1,500 XAU points and 500 XAG points. Require final absolute-
   notional mismatch no greater than 20%.
6. Submit XAU first and XAG second. A valid final package contains exactly
   one correctly directed, correctly registered, stop-protected position in
   each slot. Flatten every owned leg after a second-leg or final-validation
   failure.
7. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair orphaned, duplicated, same-side, wrong-
   symbol, wrong-magic, stopless, stale, or notional-invalid exposure.

Both news axes, the legacy news mode, and Friday close are OFF. Runtime uses
only registered MT5 D1 histories, timestamps, calendar, quotes, symbol
metadata, ATR, positions, deals, and terminal-persistent attempt state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,659 registry identities, 1,313
card files, and 45 Strategy Wiki nodes and returned no exact or fuzzy match.
The receipt is
`artifacts/qm5_xauxag_mlad_rv_preallocation_dedup_20260826.json`, SHA-256
`D425B6D0E7E4CFA8F99BFD240D7AC6BF2A5352387AA0E0FE62D959B3D2425D0B`.

Manual semantic and functional review fixes a distinct mechanic:

- `QM5_41157_xauxag-mtheilsen-rv` globally sorts the 78 month-index-
  normalized log-ratio slopes and averages indexes 38 and 39. This extraction
  profiles a median intercept separately for each slope and chooses slopes by
  the minimum thirteen-term absolute vertical loss.
- On valid log-ratio levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, this LAD
  functional is `-0.002`, while Theil-Sen is
  `+0.00303030303030303`. With the locked fade direction, the two systems
  open opposite baskets on the same valid state.
- `QM5_41159_wti-lad-tr` applies the same exact estimator to outright WTI
  month-end prices, follows its sign, and owns one WTI position. This
  extraction applies it to a synchronized paired-metal relative-price path,
  fades the sign, and owns an atomic equal-notional two-leg package.
- `QM5_13205_xau-xag-qc` fits three 504-pair cross-sectional conditional
  regressions and trades tail-envelope crossings. This extraction fits a
  single thirteen-point time slope and has no conditional beta, envelope, or
  weekly signal.
- fixed ratio z-score, return-spread z-score, OLS, CADF, MAD, quantile-tail,
  sign, sequence, path, and flow systems estimate different state objects.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback and shares neither carrier construction nor mechanic.

The paired carrier, exact month synchronization, thirteen ratio levels, time
coordinate, 78 candidates, residual-median intercepts, absolute-loss
objectives, tie convention, contrarian sides, durable attempt, aggregate
fixed-risk equal-notional package, atomicity, and next-month exit are jointly
load-bearing. Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`. Named-author peer-reviewed
  gold/silver evidence with DOI and complete preprint read, official exchange
  carrier lineage, and complete governed exact median-regression arithmetic.
  The trading conjunction is explicitly untested.
- R2: `PASS`. Clock, synchronization, endpoint count/order, logarithm,
  candidate set, residual median, objective, equality guard, final median,
  direction, attempt, aggregate risk, atomicity, and exits are exact.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs.
- R4: `PASS`. Deterministic timestamps, logarithms, sorting, absolute loss,
  finite arithmetic, ATR controls, and execution state only; no trained
  output, prohibited signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Claim And Kill Boundary

Every valid nonzero LAD slope may qualify, giving a pre-result density prior
near ten to twelve packages per full post-warm-up year. This is not market
evidence. Q02 must retire below five completed packages in any full post-
warm-up year, at zero trades, with nonpositive governed economics, or on any
synchronization, month, ratio, slope, residual, intercept, objective,
minimizer, side, attempt, risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio
neutrality. Unchanged Q09 alone owns realized book correlation. No failure
may be rescued by changing the carrier, sample, estimator, direction, risk,
hold, or by adding endpoint agreement, scale, event, seasonal, volatility,
external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, deterministic allocation, one
branch-only V5 build, strict compile/Q01, and one paced non-live logical-
basket Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or claim that the
sleeve is already decorrelated.
