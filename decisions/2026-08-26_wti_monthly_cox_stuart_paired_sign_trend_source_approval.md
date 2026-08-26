# WTI Monthly Cox-Stuart Paired-Sign Trend — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue does not authorize a manual tester
dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new structural,
low-frequency `XTIUSD` edge, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `wti-coxstuart-tr`
- proposed strategy ID:
  `MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026_S01`
- proposed source ID: `MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: compare seven fixed old/new pairs across fourteen consecutive
  completed WTI month-end log prices; follow the direction only when at least
  five of seven paired differences share one strict sign

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were reviewed before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete-paper Moskowitz-Ooi-Pedersen time-series-
   momentum evidence, explicit NYMEX WTI membership, and monthly renewal.
2. Cox and Stuart (1955), "Some Quick Sign Tests for Trend in Location and
   Dispersion," *Biometrika* 42(1-2), 80-95, DOI
   `10.1093/biomet/42.1-2.80`. The official Oxford Academic record was checked
   at `https://academic.oup.com/biomet/article-abstract/42/1-2/80/241199`.
   It confirms title, authors, journal, issue, date, pages, and DOI. The body
   is paywalled and is not represented as completely read.
3. NIST Dataplot, "Cox Stuart Test," checked at
   `https://itl.nist.gov/div898/software/dataplot/refman1/auxillar/coxstuar.htm`.
   The official implementation reference explicitly defines `c=n/2` for an
   even sample, pairs `X_i` with `X_(i+c)`, and applies a sign test to those
   paired differences.

Moskowitz, Ooi, and Pedersen support a monthly WTI own-price continuation
experiment. Cox-Stuart and the NIST implementation support the fixed
half-sample pairing and sign-count statistic. No source tests this exact
WTI-only 5-of-7 trading rule. The threshold, continuous-CFD mapping, sample,
fixed-dollar risk, stop, attempt state, and lifecycle are disclosed QM
hypotheses.

No source return, alpha, probability, Sharpe ratio, density, drawdown,
transaction cost, WTI-only result, CFD equivalence, statistical significance,
decorrelation, or portfolio-correlation statistic transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat signal, invalid state, reject, stop, or restart.
2. Exclude the current month. Reconstruct exactly fourteen consecutive
   completed broker calendar months ending with the immediately prior month.
   Retain the latest WTI D1 close in each month. Reject missing or duplicate
   months, nonchronological timestamps, nonpositive closes, or a newest
   endpoint more than ten calendar days stale.
3. In chronological order form `y[i]=ln(C[i])`, `i=0..13`. For `i=0..6`,
   calculate the fixed Cox-Stuart difference `d[i]=y[i+7]-y[i]`. Require
   exactly seven finite, nonzero differences; any tie consumes the month flat.
4. Count strict positive and negative differences. Buy only when at least five
   are positive. Sell only when at least five are negative. A 4/3 split or
   invalid state consumes the month flat. Difference magnitudes never change
   direction or risk.
5. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.5*ATR(20,D1)` broker
   hard stop. Attach no target and cap entry spread at 1,500 points.
6. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   or stopless owned exposure.

Both news axes, the legacy news mode, and Friday close are OFF.

The 5-of-7 boundary is fixed before any market result. Under an explicitly
non-empirical fair independent-sign thought experiment, `2 * (C(7,5) +
C(7,6) + C(7,7)) = 58` of 128 sign paths qualify, or 45.3125%, implying
approximately 5.44 monthly decisions per year. This is only a density prior;
real WTI pair signs are neither asserted independent nor fair, and Q02 owns
the actual frequency verdict.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed JFE trading evidence with complete-paper provenance and
  explicit WTI membership; official peer-reviewed Cox-Stuart bibliographic
  record; and a complete official NIST algorithm description. The original
  Cox-Stuart body is paywalled and the trading conjunction is explicitly
  untested.
- R2 `PASS`: clock, month selection, logarithms, all seven fixed pairs, tie
  rule, 5-of-7 direction, attempt, risk, stop, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, comparisons, integer sign
  counts, ATR risk controls, and execution state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,666 EA-registry rows, 1,317 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_coxstuart_tr_preallocation_dedup_20260826.json`,
SHA-256 `60CFBF3306A8EC69CD34B439D8EDFF300B05BB644E705D89224FAE0C94ABE8B7`.

Manual functional review fixes a new statistic rather than a renamed horizon:

- `QM5_20264_wti-rank-trend` compares every ordered pair among thirteen
  endpoints and requires an absolute Mann-Kendall score of 28. This candidate
  uses only seven disjoint endpoint pairs separated by seven months and a
  five-sign count.
- `QM5_20272_wti-qtrvote-tr` votes four non-overlapping three-month cumulative
  returns. This candidate votes seven half-sample paired differences.
- `QM5_41114_wti-mhalfagree-mom` splits daily returns inside one completed
  month into two cumulative legs. This candidate uses fourteen monthly
  endpoints and never reads the within-month path.
- `QM5_41165_wti-mrobust3-agree-tr` computes three magnitude-sensitive robust
  slopes and requires unanimous estimator signs. This candidate discards all
  magnitude after seven fixed comparisons and uses no slope.
- On log-price ranks
  `[0,8,3,7,10,2,4,6,13,11,12,9,5,1] * 0.01`, five of seven Cox-Stuart pairs
  rise, so this candidate buys; the latest-thirteen Mann-Kendall score is `2`,
  the twelve-month endpoint falls, and the four quarterly block signs split
  2/2.
- On log-price ranks
  `[12,4,0,3,7,8,13,2,5,1,9,6,10,11] * 0.01`, the Cox-Stuart signs split 4/3
  and this candidate stays flat, while the latest-thirteen Mann-Kendall score
  is `30`, the twelve-month endpoint rises, and three of four quarterly blocks
  rise.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither WTI exposure nor paired-sign trend logic.

Verdict: `CLEAN_WTI_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_TREND`.

## Kill And Safety Boundary

The pre-result density prior is five to eight completed WTI positions per full
post-warm-up year. Q02 must retire the candidate below five completed
positions in any full post-warm-up year, at zero trades, with nonpositive
governed economics, or on any month, pair, tie, sign-count, side, attempt,
risk, lifecycle, or determinism defect.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns the overlap verdict. No failed result may be rescued by changing the
sample, pairing, threshold, direction, risk, hold, or by adding a seasonal,
volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
