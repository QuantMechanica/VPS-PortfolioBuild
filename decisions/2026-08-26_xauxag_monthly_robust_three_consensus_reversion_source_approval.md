# XAU/XAG Monthly Robust-Three Consensus Reversion — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Q02 enqueue does not authorize
a manual tester dispatch or work above the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new structural,
low-frequency market-neutral-style `XAUUSD`/`XAGUSD` basket, requires
reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mrobust3-agree-rv`
- proposed strategy ID:
  `SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade the gold-minus-silver log-ratio only when exact Theil-Sen,
  least-absolute-deviation, and Siegel repeated-median slopes over the same
  thirteen completed synchronized month ends have one unanimous strict sign

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
   SHA-256
   `69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA`.
   It preserves named-author peer-reviewed gold/silver evidence, official CME
   ratio-spread carrier evidence, synchronized completed-month selection,
   exact pooled Theil-Sen arithmetic, equal-notional aggregate fixed-risk
   execution, and the atomic monthly lifecycle.
2. `strategy-seeds/sources/SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026/source.md`,
   SHA-256
   `CA90E88A038EE778D50361A6BE8BEDBD32D2AB8ED963D388AC8DDDC329BC38D5`.
   It preserves the complete-read peer-reviewed quantile-regression lineage,
   exact finite LAD breakpoint reduction, median residual intercept,
   absolute-loss objective, and fixed tie convention.
3. `strategy-seeds/sources/SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026/source.md`,
   SHA-256
   `C96F58F707CA0D622ACF955ABE82E973B60B06F7F872729701C15D3E03B43462`.
   It preserves the official peer-reviewed Andrew F. Siegel (1982)
   repeated-median method record, DOI `10.1093/biomet/69.1.242`, and exact
   nested-median arithmetic.

The three records support a bounded relative-price test and three different
robust slope functionals. No source tests their unanimous trading
conjunction. The consensus gate, continuous-CFD mapping, exact sample,
contrarian direction, fixed-dollar risk, stops, attempt state, atomic order
sequence, and lifecycle are disclosed QM hypotheses.

No source return, alpha, probability, density, Sharpe ratio, drawdown,
transaction cost, hedge ratio, neutrality, estimator superiority, CFD
equivalence, decorrelation, or portfolio-correlation statistic transfers. No
new online route, blocked content, inferred table value, or ungoverned claim
is used.

## Locked Mechanic

On the first synchronized executable `XAUUSD.DWX` D1 tick after each genuine
broker-month transition:

1. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat state, invalid state, reject, stop, partial package, or
   restart.
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker months ending with the immediately prior month. Retain
   the latest exactly timestamp-matched XAU/XAG D1 close pair in each month.
   Reject missing or duplicate months, unmatched timestamps,
   nonchronological pairs, nonpositive closes, or a newest endpoint more than
   ten calendar days stale.
3. In chronological order form
   `s[i]=ln(XAU_close[i])-ln(XAG_close[i])`, `i=0..12`, and enumerate all 78
   forward pair slopes `(s[j]-s[i])/(j-i)` for `0 <= i < j <= 12`.
4. Theil-Sen: sort all 78 slopes and average zero-based indexes 38 and 39.
5. LAD: for every one of the 78 slopes, take sorted residual index 6 as the
   intercept, sum thirteen absolute vertical residuals in chronological
   order, retain candidates within exactly `1e-12` of minimum loss, sort the
   retained slopes, and take their ordinary median.
6. Repeated median: for every pivot calculate the twelve forward-oriented
   slopes joining it to the other endpoints, average sorted indexes 5 and 6,
   then sort the thirteen pivot medians and take index 6.
7. When all three slopes are strictly positive, SELL XAU and BUY XAG. When
   all three are strictly negative, BUY XAU and SELL XAG. Any zero,
   disagreement, invalid count, or nonfinite value consumes the month flat.
   Slope magnitudes never change risk.
8. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, split
   equally by stop risk and sized against frozen `3.5*ATR(20,D1)` broker hard
   stops. Attach no targets. Cap entry spread at 1,500 XAU points and 500 XAG
   points and require no more than 20% final notional mismatch.
9. Submit XAU first and XAG second; flatten all owned legs after any
   second-leg or final-package validation failure. Close both legs at the
   first later broker month or after forty calendar days and immediately
   repair malformed owned exposure.

Both news axes, the legacy news mode, and Friday close are OFF.

## Reputable-Source Criteria

- R1 `PASS_WITH_ENSEMBLE_TRANSLATION_RISK`: named-author peer-reviewed
  gold/silver evidence with complete author-preprint provenance, official
  exchange carrier lineage, complete-read peer-reviewed median-regression
  evidence, and an official peer-reviewed repeated-median method record. The
  unanimous conjunction is explicitly untested.
- R2 `PASS`: clock, synchronization, month selection, logarithms, all three
  exact estimators, unanimous signs, attempt, aggregate risk, stops,
  atomicity, and lifecycle are locked.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 history plus native MT5 state supply every
  runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, absolute loss, comparisons, ATR risk controls, and execution state
  only; no trained output, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,665 EA-registry rows, 1,316 card
files, and 45 Strategy Wiki nodes. It found no exact match and one expected
fuzzy match, `QM5_41165_wti-mrobust3-agree-tr`, at score
`0.7142857142857143`. Evidence is
`artifacts/qm5_xauxag_mrobust3_agree_rv_preallocation_dedup_20260826.json`,
SHA-256
`2B9557DF89DA97C26E08BFF67DDAAD42A93C7D8E931CF6BEFBC3DDCAC7C5C6BB`.

Manual functional review resolves the fuzzy family:

- `QM5_41157`, `QM5_41160`, and `QM5_41164` each trade one estimator. This
  candidate computes all three complete estimators and trades only their
  strict intersection.
- On `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556`, LAD is `+0.00375`, and repeated median is `-0.0045`.
  The constituent baskets trade while this candidate is flat.
- On `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  `-0.002` while the other two estimators are positive. This candidate is
  again flat.
- On `s[i]=0.01*i`, all slopes equal `0.01` and the candidate opens SELL XAU
  / BUY XAG. On `s[i]=-0.01*i`, all equal `-0.01` and it opens BUY XAU /
  SELL XAG. The conjunction is executable in both directions.
- `QM5_41165` applies the same unanimous-estimator concept to outright WTI,
  follows the sign, and owns one crude-oil leg. This candidate computes a
  synchronized relative-metal path, fades the sign, and owns an atomic
  equal-notional basket.
- Ratio z-score, OLS, CADF, variance-ratio, return-sign, path, flow,
  volatility, and calendar rules aggregate different state objects.
  Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither this carrier nor mechanic.

Verdict: `CLEAN_AFTER_EXPECTED_WTI_CONSENSUS_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Kill And Safety Boundary

The pre-result density prior is five to twelve completed packages per full
post-warm-up year. This is not market evidence. Q02 must retire the candidate
below five completed packages in any full post-warm-up year, at zero trades,
with nonpositive governed economics, or on any synchronization, month, ratio,
slope, objective, median, consensus, side, attempt, risk, atomicity,
lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio
neutrality. Realized overlap remains exclusively a Q09 decision. No failed
result may be rescued by changing the sample, estimator, consensus rule,
direction, risk, hold, or by adding an endpoint, scale, event, seasonal,
volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
