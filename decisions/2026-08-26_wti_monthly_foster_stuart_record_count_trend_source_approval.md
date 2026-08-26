# WTI Monthly Foster-Stuart Record-Count Trend — Source Approval

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

- proposed slug: `wti-foster-record-tr`
- proposed strategy ID:
  `MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026_S01`
- proposed source ID: `MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: over thirteen consecutive completed WTI month-end closes, count
  strict new forward highs and lows; follow the record imbalance only when
  `abs(upper-lower)>=2`

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were reviewed before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves complete-paper Moskowitz-Ooi-Pedersen time-series-momentum
   evidence, explicit NYMEX WTI membership, and monthly renewal.
2. Foster and Stuart (1954), "Distribution-Free Tests in Time-Series Based
   on the Breaking of Records," *JRSS Series B* 16(1), 1-22, DOI
   `10.1111/j.2517-6161.1954.tb00143.x`. The official Oxford Academic record
   at `https://academic.oup.com/jrsssb/article/16/1/1/7026737` confirms the
   metadata and abstract description of upper/lower-record statistics for
   trend in the mean. The body is not represented as completely read.
3. Jorge Castillo-Mateo's public `RecordTest` repository at commit
   `463cca629cec54ed58dfe0f03140d29be6c8f2aa`, companion to the peer-reviewed
   *Journal of Statistical Software* package paper, DOI
   `10.18637/jss.v106.i05`. After the deterministic router selected the
   GitHub API path, `R/foster.test.R`, `R/I.record.R`, and
   `man/foster.test.Rd` were read completely. They define the unweighted
   forward `d` statistic, strict upper/lower records, and the cancelling
   trivial first record. Exact blob and SHA-256 evidence is in
   `strategy-seeds/sources/MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026/retrieval_route_20260826.json`.

Moskowitz, Ooi, and Pedersen support a monthly WTI own-price continuation
experiment. Foster-Stuart and `RecordTest` support the strict forward-record
count difference. No source tests this WTI-only thirteen-endpoint `d=2`
trading rule. The threshold, continuous-CFD mapping, fixed-dollar risk, stop,
attempt state, and lifecycle are disclosed QM hypotheses.

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
   months, nonchronological timestamps, nonpositive closes, or a newest
   endpoint more than ten calendar days stale.
3. Set the oldest close as both running high and running low. For each later
   close, count one strict upper record if it exceeds every previous close,
   one strict lower record if it is below every previous close, or one neutral
   observation otherwise. Equality is neutral, not a weak record. Require
   `upper + lower + neutral = 12`.
4. Let `d=upper-lower`. Buy only at `d>=2`; sell only at `d<=-2`; consume
   `abs(d)<2` flat. Record magnitude, p-values, backward records, and any
   fallback statistic are forbidden.
5. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.5*ATR(20,D1)` broker
   hard stop. Attach no target and cap entry spread at 1,500 points.
6. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF.

The threshold is fixed before market testing. Exact dynamic enumeration of
all `13!` distinct-rank permutations gives
`2,963,909,390 / 6,227,020,800 = 47.5975508224%` with `abs(d)>=2`, or
5.7117060987 qualifying monthly paths/year. This is only a density prior;
real WTI records are neither asserted independent nor rank-uniform, and Q02
owns the actual frequency verdict.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed JFE trading evidence with complete-paper provenance and
  explicit WTI membership; official peer-reviewed Foster-Stuart record; and
  complete exact-method files from a peer-reviewed public statistical
  package. The 1954 body and trading conjunction are explicitly untested.
- R2 `PASS`: clock, month selection, strict records, count conservation,
  threshold, direction, attempt, risk, stop, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, comparisons, integer counts, ATR risk
  controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,668 EA-registry rows, 1,319 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_foster_record_tr_preallocation_dedup_20260826.json`,
SHA-256 `BB0661A74BC9F28E2D292DDF49A01E131289A0054DB895B3FB76F54255AF7891`.

Manual functional review fixes a new statistic rather than a renamed horizon:

- `QM5_20264_wti-rank-trend` compares all ordered endpoint pairs; this rule
  compares each endpoint only with the running high and low.
- `QM5_20261_wti-lr-trend` and robust-slope cards retain magnitude and fitted
  geometry; this rule retains only strict record events.
- `QM5_41167_wti-coxstuart-tr` compares seven disjoint lag-seven pairs among
  fourteen endpoints; this rule uses thirteen endpoints and no fixed pairs.
- `QM5_10473_mql5-spearman` is an H4 FX correlation-zero-cross system; this
  rule uses no rank correlation or crossing event.
- On `[1,8,2,6,9,10,4,12,5,13,11,0,3,7]`, the latest thirteen produce four
  new highs, two new lows, and a `d=2` BUY, while endpoint, Mann-Kendall,
  Cox-Stuart, quarterly-vote, and OLS neighbors do not buy.
- On `[1,2,0,7,4,3,13,10,9,8,11,6,5,12]`, this rule is flat at `d=1`, while
  endpoint, Mann-Kendall, Cox-Stuart, quarterly-vote, and OLS neighbors buy.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither WTI exposure nor record-count logic.

Verdict: `CLEAN_WTI_MONTHLY_FOSTER_STUART_FORWARD_RECORD_D2_TREND`.

## Kill And Safety Boundary

The pre-result density prior is five to eight completed WTI positions per full
post-warm-up year. Q02 must retire the candidate below five completed
positions in any full year, at zero trades, with nonpositive governed
economics, or on any month, endpoint, record, count, side, attempt, risk,
lifecycle, or determinism defect.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns the overlap verdict. No failed result may be rescued by changing the
sample, record definition, threshold, direction, risk, hold, or by adding a
seasonal, volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
