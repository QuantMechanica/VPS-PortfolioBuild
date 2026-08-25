# WTI Monthly Repeated-Median Trend — Source Approval

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

- proposed slug: `wti-repmedian-tr`
- proposed strategy ID:
  `MOP-SIEGEL-WTI-REPMEDIAN-TREND-2026_S01`
- proposed source ID: `MOP-SIEGEL-WTI-REPMEDIAN-2026`
- traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: follow the sign of the exact repeated median of pivot-specific
  slopes over thirteen consecutive completed WTI month-end log prices

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following bounded records were read completely before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   Its complete-paper receipt records a 23-page end-to-end read of Moskowitz,
   Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, PDF SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
   The paper supports own-price continuation across the first twelve monthly
   lags, monthly renewal, and explicit WTI membership in the commodity-futures
   universe.
2. `strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`, SHA-256
   `F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E`.
   It provides governed precedent for thirteen consecutive WTI month ends,
   chronological log prices, month-index slopes, monthly attempt state, fixed
   risk, ATR stop, spread cap, and next-month lifecycle. Its global median of
   78 slopes does not transfer.
3. The complete official Oxford Academic bibliographic and abstract record
   for Andrew F. Siegel (1982), "Robust Regression Using Repeated Medians,"
   *Biometrika* 69(1), 242-244, DOI
   `10.1093/biomet/69.1.242`, read 2026-08-25 at
   `https://academic.oup.com/biomet/article-abstract/69/1/242/243029`.
   The official record supports repeated medians as a nested-median robust
   regression family and reports its high breakdown property. It is
   statistical lineage, not a trading source. The paywalled paper body was
   not used or represented as completely read.

Moskowitz, Ooi, and Pedersen support testing a slow own-price WTI trend, not a
repeated-median estimator. Siegel supplies estimator lineage, not WTI,
direction, horizon, performance, CFD mapping, risk, or lifecycle evidence.
The exact nested-median arithmetic and every execution choice below are
disclosed QM translations. No source alpha, return, Sharpe ratio, drawdown,
density, cost, CFD equivalence, or portfolio-correlation statistic transfers.

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
3. In chronological order form `y[i]=ln(C[i])` for `i=0..12`.
4. For every pivot `i`, enumerate exactly twelve forward-oriented slopes, one
   to every other endpoint `j != i`. Set `lo=min(i,j)`, `hi=max(i,j)`, and
   `b[i,j]=(y[hi]-y[lo])/(hi-lo)`. Require a positive integer denominator and
   a finite result. Sort the twelve pivot slopes ascending and define
   `m[i]=(sorted_i[5]+sorted_i[6])/2` using zero-based indexes.
5. Require exactly thirteen finite pivot medians. Sort them ascending and set
   `repeated_median=sorted_m[6]`. A strictly positive value buys WTI; a
   strictly negative value sells WTI. Exact zero or invalid arithmetic
   consumes the month flat. Signal magnitude never scales risk.
6. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` broker hard stop, no target,
   and a 1,500-point entry-spread ceiling.
7. Retain only one correctly directed, correctly registered, stop-protected
   position. Close owned exposure on the first tick in a later broker month,
   after forty calendar days, or whenever it is duplicated, wrong-symbol,
   wrong-magic, wrong-side, or stopless. Friday close and both news axes are
   OFF for the monthly hold.

The exact carrier, thirteen consecutive completed endpoints, logarithm,
pivot grouping, twelve slopes per pivot, forward orientation, inner indexes
5 and 6, outer index 6, strict sign, durable monthly attempt, fixed risk,
hard stop, and next-month exit are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`: named authors, a complete-read
  peer-reviewed JFE trading paper with DOI and explicit WTI membership, plus
  an official peer-reviewed Biometrika method record with DOI. The estimator-
  trading conjunction is explicitly untested.
- R2 `PASS`: clock, endpoint selection, log orientation, pivot membership,
  pair bounds, denominator, counts, two median stages, direction, attempt,
  risk, stop, spread, and exits are deterministic and locked before Q02.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  plus native MT5 calendar, quote, ATR, position, deal, and persistent state
  supply every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  comparisons, sorting, ATR risk controls, and execution state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical fail-closed checker scanned 4,657 EA-registry rows, 1,309 card
files, and 45 Strategy Wiki nodes. It returned one expected fuzzy neighbor at
score `0.6153846153846154`: `QM5_20271_wti-theilsen-tr`. Evidence is
`artifacts/qm5_wti_repmedian_tr_preallocation_dedup_20260825.json`, SHA-256
`6AFA0C63B92F90CE78740F10798BEF89FE1B8CCFE5802BE2D03458C7287AC654`.

Manual functional review resolves that match:

- `QM5_20271_wti-theilsen-tr` pools all 78 unique forward slopes and takes
  their global even-sample median. This candidate first groups slopes by each
  of thirteen pivots, takes thirteen separate even-sample medians, and then
  takes the median pivot. Shared endpoint count and slope primitives do not
  make the aggregation functionals equivalent.
- A fixed sign-divergence vector proves non-equivalence. For log-price levels
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, the existing
  Theil-Sen functional is `+0.00155555555555556`, while the locked repeated-
  median functional is `-0.0045`. They would take opposite positions.
- `QM5_20261_wti-lr-trend` uses OLS slope and an `R^2` gate; `QM5_20264_wti-
  rank-trend` discards slope magnitudes in an all-pairs ordinal score; and the
  median-return, trimmed-return, Huber, Hodges-Lehmann, weighted-return, path-
  efficiency, sign-vote, and endpoint-momentum families operate on different
  objects or aggregation rules.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback with neither WTI exposure nor a monthly robust slope.

Verdict:
`CLEAN_AFTER_THEILSEN_FUZZY_MATCH_AND_SIGN_DIVERGENCE_REVIEW`.

## Kill And Safety Boundary

Every valid nonzero repeated median may qualify, so the pre-result density
prior is ten to twelve positions per full post-warm-up year. This is not
market evidence. Q02 must retire the candidate below five completed positions
in any full post-warm-up year, at zero trades, with nonpositive governed
economics, or on any timestamp, month, slope, pivot, denominator, median,
side, attempt, risk, lifecycle, or determinism defect.

Direct WTI is economically different from the certified XAU/SP500/NDX/XNG
book but is not presumed uncorrelated. Q09 alone owns the realized portfolio
result. No failure may be rescued by changing the sample, estimator,
direction, carrier, risk, hold, or by adding an endpoint, volatility, event,
seasonal, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
