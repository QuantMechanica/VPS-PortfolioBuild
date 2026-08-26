# XAU/XAG Monthly Least-Absolute-Deviation Reversion — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Q02 enqueue does not authorize
a manual tester dispatch or any action above the active factory resource
ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new low-frequency
market-neutral `XAUUSD`/`XAGUSD` edge, requires reputable-source criteria and
`RISK_FIXED` backtests, identifies `QM5_12533` as the logical-basket manifest
precedent, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mlad-rv`
- proposed strategy ID:
  `SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade the sign of the exact least-absolute-deviation time slope of
  thirteen synchronized completed-month gold-minus-silver log ratios

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
   It records an end-to-end read of Schweikert (2018), "Are gold and silver
   cointegrated? New evidence from quantile cointegrating regressions,"
   *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, including Equation 10's
   Koenker-Bassett check-loss objective and the paper's adverse evidence.
2. `strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`,
   SHA-256
   `7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A`.
   It supplies governed exact arithmetic for a thirteen-observation median
   regression: all 78 pairwise-slope breakpoints, residual-median intercept,
   absolute-loss objective, fixed `1e-12` equality guard, and median
   minimizer convention. Its WTI carrier and continuation direction do not
   transfer.
3. `strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
   SHA-256
   `69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA`.
   It preserves the complete governed gold/silver and official CME ratio-
   spread lineage plus the exact two-leg month-end synchronization,
   equal-notional construction, aggregate fixed-risk, atomicity, and
   lifecycle precedent. Its Theil-Sen median signal does not transfer.

Schweikert supports testing a state-dependent gold/silver relation and warns
against assuming safe constant-vector arbitrage. The governed CME lineage
supports the intermarket ratio carrier. The LAD packet supplies a statistical
functional, not metals alpha. Their conjunction below is a transparent QM
mechanization. No source alpha, return, Sharpe ratio, density, drawdown,
transaction-cost, hedge-ratio, neutrality, CFD-equivalence, or portfolio-
correlation statistic transfers.

Two newly discovered public URLs were routed through the required source
reader and classified `DEFERRED:SOURCE_POLICY`; neither URL nor its content is
part of this approval. This decision relies only on the complete governed
repository records above.

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
   `s[i]=ln(XAU_close[i])-ln(XAG_close[i])` and `x[i]=i` for `i=0..12`.
4. Enumerate exactly 78 finite candidate slopes
   `b[i,j]=(s[j]-s[i])/(j-i)` for every `0 <= i < j <= 12`, in
   lexicographic `(i,j)` order. No fitted search bounds, subsample,
   randomization, or iterative optimizer is allowed.
5. For every candidate slope `b`, calculate thirteen residuals
   `r[i]=s[i]-b*x[i]`, sort a copy ascending, set the profiled intercept to
   `a=sorted_r[6]`, and calculate
   `L(b)=sum_i abs(s[i]-a-b*x[i])` in chronological `i=0..12` order. Require
   every residual, intercept, loss term, and objective to be finite.
6. Find the minimum objective across all 78 candidates. Retain every
   candidate within the fixed numerical equality guard `1e-12` of that
   minimum, sort the retained slopes, and take their ordinary median. This is
   `lad_slope`. The guard resolves floating-point ties and is not a tunable
   signal-strength threshold.
7. Fade the strict slope sign: positive `lad_slope` sells XAU and buys XAG;
   negative `lad_slope` buys XAU and sells XAG. Exact zero or invalid
   arithmetic consumes the month flat. Signal magnitude never changes risk.
8. Open at most one equal-target-absolute-USD-notional package under
   aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split the aggregate stop-risk budget equally, size
   each leg against a frozen `3.5*ATR(20,D1)` broker hard stop, attach no
   target, cap entry spread at 1,500 XAU points and 500 XAG points, and
   require realized absolute-notional mismatch no greater than 20%.
9. Submit XAU first and XAG second. Retain the package only when exactly one
   correctly directed, correctly registered, stop-protected position exists
   in each slot. Flatten every owned leg after any second-leg or final-package
   validation failure.
10. Close both legs on the first tick in a later broker month or after forty
    calendar days. Immediately repair an orphaned, duplicated, same-side,
    wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, the legacy news mode, and Friday close are OFF for the monthly
hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`: named-author peer-reviewed
  gold/silver evidence with DOI and complete author-preprint read, official
  exchange carrier lineage, and complete governed exact median-regression
  arithmetic. The trading conjunction is explicitly untested.
- R2 `PASS`: clock, synchronization, months, log-ratio orientation, all 78
  candidates, residual median, absolute objective, tie guard, final median,
  contrarian sides, attempt, aggregate risk, atomicity, and exits are locked.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, absolute loss,
  comparisons, ATR risk controls, and execution state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,659 EA-registry rows, 1,313 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_xauxag_mlad_rv_preallocation_dedup_20260826.json`, SHA-256
`D425B6D0E7E4CFA8F99BFD240D7AC6BF2A5352387AA0E0FE62D959B3D2425D0B`.

Manual functional review resolves the closest estimator family:

- `QM5_41157_xauxag-mtheilsen-rv` sorts the 78 month-index-normalized ratio
  slopes and averages central indexes 38 and 39. It never profiles an
  intercept or minimizes vertical absolute loss.
- On valid log-ratio levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, the locked LAD
  functional is `-0.002`, while Theil-Sen is positive
  `+0.00303030303030303`. The candidates therefore open opposite baskets on
  the same valid state.
- `QM5_41159_wti-lad-tr` uses the same governed estimator on outright WTI and
  follows its slope in one leg. This candidate applies it to a synchronized
  paired-metal relative-price path, fades the slope, and owns an atomic
  equal-notional two-leg package.
- `QM5_13205_xau-xag-qc` fits three conditional 504-pair cross-sectional
  regressions and trades tail-envelope reversion. This rule fits one
  thirteen-point time slope and uses neither conditional beta nor envelope.
- fixed ratio z-score, OLS, CADF, MAD, quantile-tail, path, sign, and flow
  systems use different state objects or estimators.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither paired-metal exposure nor monthly LAD.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Kill And Safety Boundary

Every valid nonzero LAD slope may qualify, so the pre-result density prior is
ten to twelve completed packages per full post-warm-up year. This is not
market evidence. Q02 must retire the candidate below five completed packages
in any full post-warm-up year, at zero trades, with nonpositive governed
economics, or on any synchronization, ratio, slope, residual, intercept,
objective, minimizer, side, attempt, risk, atomicity, lifecycle, or
determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio
neutrality. Q09 alone owns realized book correlation. No failed result may be
rescued by changing the carrier, sample, estimator, direction, risk, hold, or
by adding an endpoint, scale, event, seasonal, volatility, external, or
prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
