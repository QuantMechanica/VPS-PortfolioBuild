# WTI Monthly Least-Absolute-Deviation Trend — Source Approval

Date: 2026-08-25

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Q02 enqueue is not authority to dispatch a
manual tester or exceed the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new structural
low-frequency `XTIUSD` edge, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `wti-lad-tr`
- proposed strategy ID:
  `MOP-KOENKER-BASSETT-WTI-LAD-TREND-2026_S01`
- proposed source ID: `MOP-KOENKER-BASSETT-WTI-LAD-2026`
- traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: follow the sign of the exact median-regression slope that minimizes
  total absolute vertical error over thirteen consecutive completed WTI
  month-end log prices

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following bounded records were read completely before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   Its complete-paper receipt records an end-to-end read of Moskowitz, Ooi,
   and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The paper supports own-price continuation
   across the first twelve monthly lags, monthly renewal, and explicit NYMEX
   WTI membership in the commodity-futures universe.
2. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
   That governed packet records an end-to-end read of the 32-page author
   preprint for Schweikert (2018), "Are gold and silver cointegrated? New
   evidence from quantile cointegrating regressions," *Journal of Banking &
   Finance* 88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. Its Equation 10
   and bounded extraction document Koenker-Bassett check-loss regression and
   the exact simple-regression reduction to pairwise-slope breakpoints. The
   packet also preserves adverse evidence and does not assert a forecasting
   or trading result.
3. `strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`, SHA-256
   `F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E`.
   It supplies governed arithmetic and lifecycle precedent for thirteen
   consecutive WTI month ends, chronological log prices, monthly attempt
   state, fixed risk, ATR stop, spread cap, and next-month exit. Its global
   median-of-pairwise-slopes signal does not transfer.

Moskowitz, Ooi, and Pedersen support testing a slow own-price WTI trend, not a
least-absolute-deviation estimator. Schweikert and its cited Koenker-Bassett
method supply check-loss lineage, not a WTI trend rule. The exact conjunction
below is a transparent QM mechanization. No source alpha, return, Sharpe
ratio, drawdown, density, cost, continuous-CFD equivalence, estimator
superiority, or portfolio-correlation statistic transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current decision `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat signal, invalid state, reject, stop, or restart.
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker calendar months ending with the immediately prior month.
   Retain the latest D1 close in each month. Reject a missing or duplicate
   month, nonchronological timestamp, nonpositive close, or newest endpoint
   more than ten calendar days stale.
3. In chronological order form `x[i]=i` and `y[i]=ln(C[i])` for `i=0..12`.
4. Enumerate exactly 78 finite candidate slopes
   `b[i,j]=(y[j]-y[i])/(j-i)` for every `0 <= i < j <= 12`. Candidate order is
   lexicographic in `(i,j)`; the positive integer denominator is the month-
   index distance. No bound, subsample, randomization, or fitted search range
   is permitted.
5. For each candidate slope `b`, calculate thirteen residuals
   `r[i]=y[i]-b*x[i]`, sort a copy ascending, and set the profiled intercept
   `a=sorted_r[6]`. Calculate the objective
   `L(b)=sum_i abs(y[i]-a-b*x[i])` in chronological `i=0..12` order. Require
   all residuals, intercepts, terms, and objectives to be finite.
6. Find the smallest objective across the 78 candidates. Retain every
   candidate whose objective is within the fixed numerical equality guard
   `1e-12` of that minimum, sort the retained slopes, and take their ordinary
   median (middle value for odd count; mean of the two central values for
   even count). This is `lad_slope`. The guard is locked for floating-point
   tie resolution and is not a performance parameter.
7. A strictly positive `lad_slope` buys WTI; a strictly negative value sells
   WTI. Exact zero or invalid arithmetic consumes the month flat. Signal
   magnitude never scales risk.
8. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` broker hard stop, no target,
   and a 1,500-point entry-spread ceiling.
9. Retain only one correctly directed, correctly registered, stop-protected
   position. Close owned exposure on the first tick in a later broker month,
   after forty calendar days, or whenever it is duplicated, wrong-symbol,
   wrong-magic, wrong-side, or stopless. Friday close and both news axes are
   OFF for the monthly hold.

The exact carrier, thirteen consecutive completed endpoints, logarithm,
78 pairwise breakpoint slopes, median profiled intercept, absolute-loss
objective, fixed tie guard, median minimizer convention, strict sign, durable
monthly attempt, fixed risk, hard stop, and next-month exit are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`: named authors, a complete-read
  peer-reviewed JFE trading paper with DOI and explicit WTI membership, plus
  a complete-read peer-reviewed JBF quantile-regression packet with DOI and
  an author preprint. The estimator-trading conjunction is explicitly
  untested.
- R2 `PASS`: clock, endpoint selection, log orientation, all 78 candidates,
  residuals, median intercept, objective order, tie guard, final median,
  direction, attempt, risk, stop, spread, and exits are deterministic and
  locked before Q02.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  plus native MT5 calendar, quote, ATR, position, deal, and persistent state
  supply every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, absolute loss, ATR risk controls, and execution state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical fail-closed checker scanned 4,658 EA-registry rows, 1,311 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_lad_tr_preallocation_dedup_20260825.json`, SHA-256
`C53AE2817A8139C7D57C376B0913B9A9F201B48447A285530082B3569114B308`.

Manual functional review also resolves the estimator family:

- `QM5_20271_wti-theilsen-tr` takes the median of 78 pairwise slopes and does
  not minimize a fitted-intercept absolute-loss objective.
- `QM5_41158_wti-repmedian-tr` groups slopes by each pivot, takes thirteen
  inner medians, and then an outer median. It has no profiled intercept or
  loss minimization.
- On fixed log-price levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, this locked LAD
  functional is `-0.002`, while Theil-Sen is
  `+0.00303030303030303`, repeated median is
  `+0.00380952380952381`, OLS is `+0.00203296703296703`, and the endpoint
  slope is `+0.00416666666666667`. The LAD rule takes the opposite side on
  one valid state and therefore is not a parameter alias of those systems.
- `QM5_13205_xau-xag-qc` fits three conditional XAU/XAG price regressions on
  504 synchronized observations and trades tail-envelope reversion in a
  two-leg metals basket. This candidate fits one median-regression time slope
  on thirteen WTI month ends and follows its sign in one direct energy leg.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback with neither WTI exposure nor a monthly robust path slope.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Kill And Safety Boundary

Every valid nonzero LAD slope may qualify, so the pre-result density prior is
ten to twelve positions per full post-warm-up year. This is not market
evidence. Q02 must retire the candidate below five completed positions in any
full post-warm-up year, at zero trades, with nonpositive governed economics,
or on any timestamp, month, slope, residual, intercept, objective, minimizer,
side, attempt, risk, lifecycle, or determinism defect.

Direct WTI is economically different from the certified XAU/SP500/NDX/XNG
book but is not presumed uncorrelated. Q09 alone owns the realized portfolio
result. No failure may be rescued by changing the sample, estimator,
direction, carrier, equality guard, risk, hold, or by adding an endpoint,
volatility, event, seasonal, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
