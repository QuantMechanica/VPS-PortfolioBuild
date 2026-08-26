---
source_id: SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026
title: XAU/XAG thirteen-month robust-three unanimous-slope ratio reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and governed method research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_xauxag_monthly_robust_three_consensus_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026
  - SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026
  - SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026
parent_sha256:
  SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026: 69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA
  SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026: CA90E88A038EE778D50361A6BE8BEDBD32D2AB8ED963D388AC8DDDC329BC38D5
  SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026: C96F58F707CA0D622ACF955ABE82E973B60B06F7F872729701C15D3E03B43462
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - xauxag-mrobust3-agree-rv
---

# XAU/XAG Thirteen-Month Robust-Three Consensus Reversion Source Packet

## Approved Sources Of Record

The gold/silver relationship source is Karsten Schweikert (2018), "Are gold
and silver cointegrated? New evidence from quantile cointegrating
regressions," *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. The governed parent packets preserve a
complete read of the 32-page author preprint, including its adverse evidence,
and the official CME Group gold/silver ratio-spread carrier record.

The three exact estimator records are:

1. `strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
   which fixes thirteen synchronized completed-month log ratios, all 78
   forward pair slopes, and the exact pooled even median;
2. `strategy-seeds/sources/SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026/source.md`,
   which preserves the Koenker-Bassett median-regression lineage and fixes
   the 78-breakpoint finite LAD reduction, median residual intercept,
   thirteen-term absolute-loss objective, and tie convention; and
3. `strategy-seeds/sources/SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026/source.md`,
   which preserves Andrew F. Siegel (1982), "Robust Regression Using Repeated
   Medians," *Biometrika* 69(1), 242-244, DOI
   `10.1093/biomet/69.1.242`, through the official method record and fixes the
   exact nested-median arithmetic.

All three bounded parent records were read completely before the durable
OWNER source approval at
`decisions/2026-08-26_xauxag_monthly_robust_three_consensus_reversion_source_approval.md`.
No new online route, blocked source body, inferred table value, or ungoverned
performance claim is used.

## Source Findings Used

Schweikert supports testing a related but state-dependent gold/silver price
relation while supplying adverse evidence against a universal constant-vector
arbitrage. CME supports the gold/silver ratio as an intermarket carrier and
records shared precious-metal and USD drivers alongside different monetary,
safe-haven, industrial, and business-cycle exposure. The method records
supply three distinct robust slope functionals.

No source tests the unanimous conjunction below. None establishes that a
trailing robust slope of the ratio will revert, that agreement improves
economics, or that equal-notional CFD legs are neutral. The exact sample,
calendar, synchronization, log-ratio orientation, estimator conjunction,
contrarian direction, continuous-CFD mapping, aggregate fixed risk, stops,
spread caps, persistent attempt state, atomic order sequence, and lifecycle
are transparent QM hypotheses.

No source return, alpha, probability, trade density, Sharpe ratio, drawdown,
transaction cost, hedge ratio, neutrality, estimator superiority, CFD
equivalence, decorrelation, or portfolio-correlation statistic transfers.

## Locked Robust-Three Statistic

On the first synchronized executable D1 tick of a genuine new broker month,
exclude the current month and reconstruct exactly thirteen consecutive
completed broker calendar months ending with the immediately prior month.
Retain the latest exactly timestamp-matched `XAUUSD.DWX` and `XAGUSD.DWX`
close pair in every month. Missing or duplicate months, unmatched timestamps,
nonchronological pairs, nonpositive closes, and stale endpoints are invalid.

For chronological pairs `i=0..12`, define:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])

pair slopes = (s[j]-s[i])/(j-i), every 0 <= i < j <= 12, exactly 78
theilsen = average(sorted_pair_slopes[38], sorted_pair_slopes[39])

for every pair-slope candidate b:
  intercept = sorted(s[i]-b*i)[6]
  loss = chronological sum(abs(s[i]-intercept-b*i)), i=0..12
lad = ordinary median of every candidate within 1e-12 of minimum loss

for every pivot i=0..12:
  form twelve forward-oriented slopes joining i to every j != i
  pivot_median[i] = average(sorted_pivot[5], sorted_pivot[6])
repeated_median = sorted(pivot_median)[6]

all three > 0 => SELL XAU, BUY XAG
all three < 0 => BUY XAU, SELL XAG
otherwise     => FLAT
```

Require exactly thirteen finite ratios, exactly 78 finite pair slopes,
exactly 78 finite LAD profiles and nonnegative objectives, at least one LAD
minimizer, exactly twelve slopes in each of thirteen pivot groups, exactly
thirteen finite pivot medians, and finite final statistics. Current-month
prices are excluded. There is no fallback, majority vote, weight, magnitude
threshold, endpoint gate, fitted scale, OLS, z-score, seasonal state,
volatility signal, external series, or prior-result input. Exact zero,
estimator disagreement, or any invalid state consumes the month flat.
Statistic magnitudes never change risk.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, and an
   entry attempt no later than 180 elapsed minutes after the raw current host
   D1 bar open in a genuine new broker month.
2. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order checks. A flat state,
   invalid state, reject, stop, partial package, or restart never retries the
   month.
3. Require the immediately prior thirteen consecutive broker-month keys,
   exact pair timestamps, positive finite closes, strict chronological order,
   and a newest endpoint no more than ten calendar days stale.
4. Compute the exact Theil-Sen, LAD, and repeated-median functionals above.
   Fade only one unanimous strict sign with the locked opposite-leg mapping.
5. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   aggregate stop-risk budget equally; size each leg against its frozen
   `3.5*ATR(20,D1)` broker hard stop; attach no target; cap spread at 1,500
   XAU points and 500 XAG points; and require realized absolute-notional
   mismatch no greater than 20%.
6. Submit XAU first and XAG second. Retain the package only when exactly one
   correctly directed, correctly registered, stop-protected position exists
   in each slot. Flatten every owned leg immediately after a second-leg or
   final-package validation failure.
7. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, the legacy news mode, and Friday close are OFF. Runtime uses
only registered native MT5 D1 histories, timestamps, calendar, quotes, symbol
metadata, ATR, positions, deals, and terminal-persistent attempt state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,665 registry identities, 1,316
card files, and 45 Strategy Wiki nodes. It found no exact identity and one
expected fuzzy match, the analogous outright-WTI unanimous-consensus card at
score `0.7142857142857143`. The durable receipt is
`artifacts/qm5_xauxag_mrobust3_agree_rv_preallocation_dedup_20260826.json`,
SHA-256
`2B9557DF89DA97C26E08BFF67DDAAD42A93C7D8E931CF6BEFBC3DDCAC7C5C6BB`.

Manual semantic and functional review resolves the family:

- `QM5_41157_xauxag-mtheilsen-rv`, `QM5_41160_xauxag-mlad-rv`, and
  `QM5_41164_xauxag-mrepmedian-rv` each trade one estimator. This extraction
  computes all three complete estimators and trades only their strict
  intersection.
- On valid log-ratio levels
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556`, LAD is `+0.00375`, and repeated median is `-0.0045`.
  The three single-estimator systems take positions, including opposite
  packages, while this extraction consumes the month flat.
- On valid log-ratio levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  `-0.002` while Theil-Sen and repeated median are positive. The extraction
  is again flat rather than aliasing any constituent.
- On `s[i]=0.01*i`, all three slopes equal `0.01` and the extraction sells
  XAU while buying XAG. On `s[i]=-0.01*i`, all three equal `-0.01` and it
  buys XAU while selling XAG. The conjunction is executable in both
  directions.
- `QM5_41165_wti-mrobust3-agree-tr` uses outright WTI log prices, follows the
  consensus sign, and owns one crude-oil leg. This extraction uses a
  synchronized gold-minus-silver relative path, fades the sign, and owns an
  atomic equal-notional two-leg package.
- Ratio z-score, OLS, CADF, variance-ratio, return-sign, path, flow,
  volatility, and calendar systems estimate different state objects.
  Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither this carrier nor mechanic.

The paired carrier, thirteen synchronized completed-month endpoints,
gold-minus-silver orientation, all three complete estimators, strict unanimous
sign, contrarian mapping, consumed month, aggregate fixed-risk equal-notional
package, atomicity, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_WTI_CONSENSUS_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ENSEMBLE_TRANSLATION_RISK`. Named-author peer-reviewed
  gold/silver evidence with DOI and complete author-preprint read, official
  exchange carrier lineage, complete-read peer-reviewed median-regression
  lineage, and named-author peer-reviewed repeated-median method lineage.
  The unanimous conjunction is explicitly untested.
- R2: `PASS`. Clock, synchronization, endpoint count/order, logarithms, all
  three estimator definitions, unanimous signs, attempt, aggregate risk,
  stops, atomicity, and lifecycle are locked.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply
  every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, sorting, absolute loss,
  finite arithmetic, comparisons, ATR risk controls, and execution state
  only; no trained output, prohibited signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The pre-result density prior is five to twelve completed packages per full
post-warm-up year. This is not market evidence. Q02 must retire below five
completed packages in any full post-warm-up year, at zero trades, with
nonpositive governed economics, or on any synchronization, month, ratio,
slope, objective, median, consensus, side, attempt, risk, atomicity,
lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized book correlation. No failed result may be
rescued by changing the carrier, sample, estimator, consensus rule,
direction, risk, hold, or by adding endpoint, scale, event, seasonal,
volatility, external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, deterministic allocation, one
branch-only V5 build, strict compile/Q01, and one paced non-live logical-basket
Q02 handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or decorrelation claim.
