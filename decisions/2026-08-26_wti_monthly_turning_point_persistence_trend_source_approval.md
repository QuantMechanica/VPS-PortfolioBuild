# WTI Monthly Turning-Point Persistence Trend — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue does not authorize tester dispatch or
work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new structural,
low-frequency `XTIUSD` edge, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `wti-mturnpoint-tr`
- proposed strategy ID:
  `MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026_S01`
- proposed source ID: `MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: count strict local extrema among thirteen completed WTI month-end
  closes, require the count below its iid null mean, then follow the
  oldest-to-newest endpoint direction

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were reviewed before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves complete-paper Moskowitz-Ooi-Pedersen time-series-momentum
   evidence, explicit NYMEX WTI membership, and monthly renewal.
2. W. Allen Wallis and Geoffrey H. Moore (1941), "A Significance Test for
   Time Series Analysis," *Journal of the American Statistical Association*
   36(215), 401-409, DOI `10.1080/01621459.1941.10500577`. Crossref confirms
   the named authors, title, journal, issue, pages, publisher, and date. The
   article body is not represented as completely read because the deterministic
   source router classified the public PDF route `DEFERRED:SOURCE_POLICY`.
3. Andrew Hart and Servet Martinez's CRAN `spgs` 1.0-4 source mirror at public
   GitHub commit `987257510f8b2a7ffe903d6b840021befbb4de58`. After the
   deterministic router selected the GitHub API path, `DESCRIPTION`,
   `R/auxtests.R`, and `man/turningpoint.test.Rd` were read completely. They
   define a strict peak/trough, the total turning-point count, null mean
   `2*(n-2)/3`, null variance `(16*n-29)/90`, and the independence-test
   interpretation. Exact blob and SHA-256 evidence is in
   `strategy-seeds/sources/MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026/retrieval_route_20260826.json`.

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. Wallis and Moore supply peer-reviewed phase-frequency
lineage, while the complete `spgs` files supply the exact local-extrema count
and null moments. No source tests this WTI-only thirteen-endpoint,
below-null-mean, endpoint-direction trading conjunction. The integer boundary,
continuous-CFD mapping, fixed-dollar risk, stop, attempt state, and lifecycle
are disclosed QM hypotheses.

No source return, alpha, probability, Sharpe ratio, density, drawdown,
transaction cost, WTI-only result, CFD equivalence, statistical significance,
decorrelation, or portfolio-correlation statistic transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat signal, invalid state, reject, stop, or restart.
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker calendar months ending with the immediately prior month.
   Retain the latest WTI D1 close in each month. Reject missing or duplicate
   months, nonchronological timestamps, nonpositive closes, any pairwise equal
   closes, or a newest endpoint more than ten calendar days stale.
3. For each interior endpoint `i=1..11`, count one turning point only when it
   is a strict local peak (`C[i-1]<C[i]>C[i+1]`) or strict local trough
   (`C[i-1]>C[i]<C[i+1]`). Require `0<=TP<=11`.
4. For `n=13`, the iid null mean is `2*(13-2)/3=22/3`. Qualify as persistent
   only when `TP<22/3`, equivalently integer `TP<=7` or `3*TP<22`. No p-value,
   continuity correction, normal approximation, fitted parameter, or phase-
   length chi-square may replace this precommitted mean boundary.
5. If qualified, buy only when `C[12]>C[0]` and sell only when
   `C[12]<C[0]`. A nonqualifying or invalid path consumes the month flat.
   Turning-point count never changes side or risk.
6. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.5*ATR(20,D1)` broker
   hard stop. Attach no target and cap entry spread at 1,500 points.
7. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF.

The `TP<=7` boundary is fixed before market testing. It is the exact integer
split below the method's iid null mean, not a statistical-significance claim.
An iid continuous thought experiment gives a pre-result density prior near one
half, or about six monthly decisions/year. WTI month ends are not asserted
iid, continuous, or random; Q02 owns actual frequency and economics.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed JFE trading evidence with complete-paper provenance and
  explicit WTI membership; a peer-reviewed JASA method record; and complete
  exact-method files from a CRAN package. The 1941 article body and trading
  conjunction are explicitly untested.
- R2 `PASS`: clock, month selection, strict local-extrema comparisons, count
  bounds, mean boundary, endpoint direction, attempt, risk, stop, and
  lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, comparisons, integer arithmetic, ATR
  risk controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,670 EA-registry rows, 1,321 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_mturnpoint_tr_preallocation_dedup_20260826.json`,
SHA-256 `371C5BF9BC108012F6FF8C53E6184CD234355995545A130E837DB7690C73B415`.

Manual functional review fixes a new path statistic rather than a renamed
horizon:

- `QM5_20273_wti-signrun-tr` retains the longest positive and negative runs
  and requires a unique run of at least four; this rule counts every strict
  direction reversal and uses only the endpoint comparison for side.
- `QM5_20264_wti-rank-trend` counts signs across all 78 ordered endpoint
  pairs; this rule inspects only eleven overlapping local triples.
- `QM5_20274_wti-path-eff` retains return magnitudes in a net/path ratio; this
  rule is magnitude-free after strict comparisons.
- `QM5_41169_wti-foster-record-tr` counts new running extremes; this rule
  counts local peaks and troughs even when neither is a record.
- `QM5_41170_wti-bartels-rank-tr` sums squared adjacent rank distances; this
  rule counts sign changes only and never assigns ranks.
- On zero-based ranks `[8,4,1,7,9,10,3,12,6,0,5,2,11]`, `TP=7` and the
  endpoint rises, so this rule buys. Bartels `NM=383`, Mann-Kendall `S=0`,
  Foster-Stuart `d=0`, and longest runs `L+=3,L-=2` all stay flat.
- On `[5,1,6,2,0,8,3,7,12,4,11,9,10]`, `TP=9`, so this rule stays flat,
  while Bartels `NM=309` and Mann-Kendall `S=36` both qualify long.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither WTI exposure nor monthly path-shape logic.

Verdict: `CLEAN_WTI_MONTHLY_TURNING_POINT_COUNT_LT_NULL_MEAN_ENDPOINT_TREND`.

## Kill And Safety Boundary

The pre-result density prior is five to eight completed WTI positions per full
post-warm-up year. Q02 must retire the candidate below five completed positions
in any full year, at zero trades, with nonpositive governed economics, or on
any month, endpoint, turning-point, side, attempt, risk, lifecycle, or
determinism defect.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns the overlap verdict. No failed result may be rescued by changing the
sample, comparison rule, boundary, direction, risk, hold, or by adding a
seasonal, volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
