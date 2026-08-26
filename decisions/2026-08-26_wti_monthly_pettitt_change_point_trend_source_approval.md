# WTI Monthly Pettitt Central Change-Point Trend — Source Approval

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

- proposed slug: `wti-mpettitt-shift-tr`
- proposed strategy ID: `MOP-PETTITT-WTI-MSHIFT-TREND-2026_S01`
- proposed source ID: `MOP-PETTITT-WTI-MSHIFT-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: locate the unique dominant central rank-sum change point among
  thirteen completed WTI month-end closes and continue in the direction of
  the post-change level shift

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were reviewed before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves complete-paper Moskowitz-Ooi-Pedersen time-series-momentum
   evidence, explicit NYMEX WTI membership, and monthly renewal.
2. A. N. Pettitt (1979), "A Non-Parametric Approach to the Change-Point
   Problem," *Applied Statistics* 28(2), 126-135, DOI
   `10.2307/2346729`. Crossref and the publisher record confirm the named
   author and bibliographic identity. The article body is not represented as
   completely read because the deterministic source router classified the
   publisher route `DEFERRED:SOURCE_POLICY`.
3. Thorsten Pohlert's CRAN `trend` 1.1.7 source mirror at public GitHub commit
   `d0ec3cf8b99b4f3226f5211f592955b85565721d`. After the deterministic router
   selected the GitHub API path, `DESCRIPTION`, `R/pettitt.test.R`, and
   `man/pettitt.test.Rd` were read completely. They define the rank-sum path,
   absolute maximum, probable change-point location, central-tendency-shift
   interpretation, and approximate probability formula. Exact blob and
   SHA-256 evidence is in
   `strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/retrieval_route_20260826.json`,
   SHA-256 `3518328F7A050B95C32D8349AB770D7DBE690CD603327C71087F9A4F5159DEAC`.
4. The governed composite packet
   `strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md`,
   SHA-256 `A80A6F6C87C7FB1D5D9E4911A36C5CAFE7005319F4C844F0550B697577BA3C98`.

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. Pettitt supplies peer-reviewed change-point lineage,
while the complete `trend` files supply the exact rank-sum statistic. No
source tests this WTI-only thirteen-endpoint, unique-central-split,
post-shift-continuation conjunction. The central band, continuous-CFD mapping,
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
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker calendar months ending with the immediately prior month.
   Retain the latest WTI D1 close in each month. Reject missing or duplicate
   months, nonchronological timestamps, nonpositive closes, any pairwise equal
   closes, or a newest endpoint more than ten calendar days stale.
3. Assign strict ranks 1 through 13. For each `k=1..12`, compute
   `U[k]=2*sum(R[0..k-1])-14*k`. Require every `U[k]` even and in `[-42,42]`.
4. Let `U*=max(abs(U[k]))`. Require `U*>0`, exactly one maximizing `K`, and
   `4<=K<=9`, leaving at least four completed observations on both sides.
5. Buy only when `U[K]<0` because earlier ranks are lower than the post-shift
   regime. Sell only when `U[K]>0`. A tied or edge maximum, invalid rank path,
   or zero sign consumes the month flat. No p-value or endpoint-direction
   fallback is permitted.
6. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.5*ATR(20,D1)` broker
   hard stop. Attach no target and cap entry spread at 1,500 points.
7. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. The central band is
fixed before market testing and is a density-oriented QM boundary, not a
statistical-significance claim. Q02 owns actual frequency and economics.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed JFE trading evidence with complete-paper provenance and
  explicit WTI membership; a peer-reviewed Pettitt method record; and
  complete exact-method files from a CRAN package. The 1979 article body and
  trading conjunction are explicitly untested.
- R2 `PASS`: clock, month selection, strict ranks, twelve cumulative sums,
  unique maximum, central band, side, attempt, risk, stop, and lifecycle are
  locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, ranks, integer arithmetic, ATR risk
  controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,671 EA-registry rows, 1,322 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_mpettitt_shift_tr_preallocation_dedup_20260826.json`,
SHA-256 `F06EAE90ED88E139C0CFA9BA2A4B02729F762DCDB5343EA6C931EEC54108679F`.

Manual functional review fixes a new change-point statistic rather than a
renamed horizon:

- `QM5_41170_wti-bartels-rank-tr` sums squared adjacent rank moves; this rule
  scans signed cumulative rank sums and retains the maximum split location.
- `QM5_41171_wti-mturnpoint-tr` counts strict local extrema and takes side
  from the endpoints; this rule uses neither local extrema nor endpoint side.
- `QM5_41169_wti-foster-record-tr` counts new running extremes; this rule
  estimates one central two-sample level separation.
- On `[0,7,4,6,1,9,10,5,11,2,8,3,12]`, `U*=24` uniquely at `K=5` with
  `U[K]=-24`, so this rule buys. Bartels `NM=436` and turning points `TP=10`
  both stay flat.
- On `[0,1,12,5,4,6,7,11,9,2,3,10,8]`, the maximum is `22` at edge split
  `K=2`, so this rule stays flat. Bartels `NM=300` and turning points `TP=5`
  both qualify long from their rising endpoints.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither WTI exposure nor monthly change-point
  logic.

Verdict: `CLEAN_WTI_MONTHLY_PETTITT_UNIQUE_CENTRAL_SHIFT_CONTINUATION`.

## Kill And Safety Boundary

The pre-result density prior is four to eight completed WTI positions per full
post-warm-up year. Q02 must retire the candidate below four completed
positions in any full year, at zero trades, with nonpositive governed
economics, or on any month, endpoint, rank, split, side, attempt, risk,
lifecycle, or determinism defect.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns the overlap verdict. No failed result may be rescued by changing the
sample, rank rule, central band, direction, risk, hold, or by adding a
seasonal, volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
