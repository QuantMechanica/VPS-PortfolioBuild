# XAU/XAG Monthly Repeated-Median Reversion — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Q02 enqueue does not authorize
a manual tester dispatch or work above the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new low-frequency
market-neutral `XAUUSD`/`XAGUSD` edge, requires reputable-source criteria and
`RISK_FIXED` backtests, identifies `QM5_12533` as the logical-basket manifest
precedent, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mrepmedian-rv`
- proposed strategy ID:
  `SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade the sign of the exact Siegel-style repeated median of thirteen
  pivot-specific slope medians over synchronized completed-month
  gold-minus-silver log ratios

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
   It preserves an end-to-end read of Schweikert (2018), "Are gold and silver
   cointegrated? New evidence from quantile cointegrating regressions,"
   *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, including the paper's adverse evidence
   against assuming a safe constant-vector arbitrage relation.
2. `strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md`, SHA-256
   `199D39CB5ECAFC7B57F19BA7932DBEF6558529DD68AE00B66AD4531C7FA48E91`.
   It preserves the official Oxford Academic bibliographic and abstract
   record for Andrew F. Siegel (1982), "Robust Regression Using Repeated
   Medians," *Biometrika* 69(1), 242-244, DOI
   `10.1093/biomet/69.1.242`, and fixes exact thirteen-pivot nested-median
   arithmetic. Its WTI carrier and continuation direction do not transfer.
3. `strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
   SHA-256
   `69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA`.
   It preserves the complete governed gold/silver and official CME ratio-
   spread lineage plus exact two-leg month-end synchronization, equal-
   notional construction, aggregate fixed risk, atomicity, and lifecycle.
   Its pooled Theil-Sen statistic does not transfer.

Schweikert supports testing a state-dependent gold/silver relation and warns
against assuming a universal equilibrium. The governed CME lineage supports
the intermarket carrier. Siegel supplies nested-median robust-regression
lineage, not a metals alpha. Their conjunction below is an explicitly
untested QM mechanization. No source return, alpha, Sharpe ratio, density,
drawdown, transaction cost, hedge ratio, neutrality, CFD equivalence,
robustness improvement, or portfolio-correlation statistic transfers.

No new online route, blocked content, inferred table value, or ungoverned
performance claim is part of this approval.

## Locked Mechanic

On the first synchronized executable D1 tick after each genuine broker-month
transition:

1. Persist the current decision `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat signal, invalid state, reject, partial package, stop, or
   restart.
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker calendar months ending with the immediately prior month.
   Retain the latest exactly timestamp-matched `XAUUSD.DWX` and `XAGUSD.DWX`
   D1 close pair in each month. Reject missing or duplicate months, unmatched
   timestamps, nonchronological pairs, nonpositive closes, or a newest pair
   more than ten calendar days stale.
3. In chronological order form
   `s[i]=ln(XAU_close[i])-ln(XAG_close[i])` for `i=0..12`.
4. For every pivot `i`, enumerate exactly twelve forward-oriented slopes to
   every other endpoint `j != i`. Set `lo=min(i,j)`, `hi=max(i,j)`, and
   `b[i,j]=(s[hi]-s[lo])/(hi-lo)`. Require a positive integer denominator and
   a finite result.
5. Sort each pivot's twelve slopes ascending and define
   `m[i]=(sorted_i[5]+sorted_i[6])/2` using zero-based indexes. Require exactly
   thirteen finite pivot medians, sort them, and set
   `repeated_median=sorted_m[6]`.
6. Fade the strict statistic sign: positive `repeated_median` sells XAU and
   buys XAG; negative `repeated_median` buys XAU and sells XAG. Exact zero or
   invalid arithmetic consumes the month flat. Signal magnitude never changes
   risk.
7. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   aggregate stop-risk budget equally, size each leg against a frozen
   `3.5*ATR(20,D1)` broker hard stop, attach no target, cap entry spread at
   1,500 XAU points and 500 XAG points, and require realized absolute-notional
   mismatch no greater than 20%.
8. Submit XAU first and XAG second. Retain the package only when exactly one
   correctly directed, correctly registered, stop-protected position exists
   in each slot. Flatten every owned leg after any second-leg or final-package
   validation failure.
9. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, the legacy news mode, and Friday close are OFF for the monthly
hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`: named-author peer-reviewed
  gold/silver evidence with DOI and complete author-preprint read, official
  exchange carrier lineage, and a named-author peer-reviewed nested-median
  method record with DOI. The trading conjunction is explicitly untested.
- R2 `PASS`: clock, synchronization, months, log-ratio orientation, thirteen
  pivot groups, twelve slopes per pivot, forward orientation, both median
  stages, contrarian sides, attempt, aggregate risk, atomicity, and exits are
  locked.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, finite arithmetic,
  comparisons, ATR risk controls, and execution state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,663 EA-registry rows, 1,314 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_xauxag_mrepmedian_rv_preallocation_dedup_20260826.json`,
SHA-256
`D831A578286D639AFD34C8BC6AA02A9D6FEF93E3B5AD14E1DBC346691D8CB28F`.

Manual functional review resolves the closest estimator family:

- `QM5_41157_xauxag-mtheilsen-rv` pools all 78 unique slopes and takes one
  global even-sample median. This candidate takes thirteen separate medians
  over pivot-specific groups and then one outer median.
- `QM5_41160_xauxag-mlad-rv` profiles an intercept for each candidate slope,
  minimizes vertical absolute loss, and takes the median minimizer. This
  candidate has no fitted intercept or loss objective.
- On valid gold-minus-silver log-ratio levels
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556`, LAD is `+0.00375`, and the locked repeated median is
  `-0.0045`. The new candidate therefore opens the opposite basket from both
  existing systems on the same valid state.
- `QM5_41158_wti-repmedian-tr` uses the same governed estimator on outright
  WTI, follows its sign, and owns one energy leg. This candidate applies the
  statistic to a synchronized paired-metal relative-price path, fades it, and
  owns an atomic equal-notional two-leg package.
- `QM5_13205_xau-xag-qc` fits three conditional 504-pair cross-sectional
  regressions and trades tail-envelope reversion. This rule fits no alpha,
  beta, conditional envelope, scale, or threshold.
- Fixed ratio z-score, OLS, CADF, MAD, daily-return pseudomedian, path, sign,
  flow, and calendar systems use different state objects or estimators.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither paired-metal exposure nor a monthly robust
  slope.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Kill And Safety Boundary

Every valid nonzero repeated median may qualify, so the pre-result density
prior is ten to twelve completed packages per full post-warm-up year. This is
not market evidence. Q02 must retire the candidate below five completed
packages in any full post-warm-up year, at zero trades, with nonpositive
governed economics, or on any synchronization, ratio, pivot, slope, median,
side, attempt, risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Q09 alone owns realized book correlation. No failed result may be rescued by
changing the carrier, sample, estimator, direction, risk, hold, or by adding
an endpoint, scale, event, seasonal, volatility, external, or prior-result
gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
