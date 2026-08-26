# WTI Monthly Bartels Rank-Persistence Trend — Source Approval

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

- proposed slug: `wti-bartels-rank-tr`
- proposed strategy ID:
  `MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026_S01`
- proposed source ID: `MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: rank thirteen completed WTI month-end closes, require the Bartels
  rank von-Neumann successive-difference ratio below its null mean, then
  follow the oldest-to-newest endpoint direction

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were reviewed before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves complete-paper Moskowitz-Ooi-Pedersen time-series-momentum
   evidence, explicit NYMEX WTI membership, and monthly renewal.
2. Robert Bartels (1982), "The Rank Version of von Neumann's Ratio Test for
   Randomness," *Journal of the American Statistical Association* 77(377),
   40-46, DOI `10.1080/01621459.1982.10477764`. The Crossref DOI record
   confirms author, title, journal, issue, pages, publisher, and date. The
   original article body is not represented as completely read.
3. Frederico Caeiro and Ayana Mateus's CRAN `randtests` 1.0.2 source mirror
   at public GitHub commit
   `7244d86764445e657634c9ae4d59ce942a5fcbc8`. After the deterministic
   router selected the GitHub API path, `R/bartels.rank.test.R`,
   `man/bartels.rank.test.Rd`, and `DESCRIPTION` were read completely. They
   define the rank convention, successive-rank squared-difference numerator,
   denominator, null mean `2`, variance, and the left-sided trend
   interpretation. Exact blob and SHA-256 evidence is in
   `strategy-seeds/sources/MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026/retrieval_route_20260826.json`.

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. Bartels and the complete `randtests` method files
support the rank successive-difference statistic and the interpretation of a
low ratio as trend rather than systematic oscillation. No source tests this
WTI-only thirteen-endpoint, below-null-mean, endpoint-direction trading rule.
The mean boundary, continuous-CFD mapping, fixed-dollar risk, stop, attempt
state, and lifecycle are disclosed QM hypotheses.

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
   months, nonchronological timestamps, nonpositive closes, any pairwise
   equal closes, or a newest endpoint more than ten calendar days stale.
3. In chronological order assign ranks `R[i]` from 1 (smallest close) to 13
   (largest close). Require every rank exactly once and
   `sum((R[i]-7)^2)=182`.
4. Calculate `NM=sum((R[i+1]-R[i])^2, i=0..11)` and `RVN=NM/182`.
   Qualify as rank-persistent only when `RVN<2`, equivalently integer
   `NM<364`. No p-value, finite-sample table, Beta approximation, or fitted
   parameter may replace this precommitted mean boundary.
5. If qualified, buy only when `C[12]>C[0]` and sell only when
   `C[12]<C[0]`. A nonqualifying or invalid path consumes the month flat.
   Statistic magnitude never changes side or risk.
6. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.5*ATR(20,D1)` broker
   hard stop. Attach no target and cap entry spread at 1,500 points.
7. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF.

The `RVN<2` boundary is fixed before market testing. The method's normal and
Beta null approximations are centered at `2`, so a rank-uniform thought
experiment gives a pre-result density prior near one half, or about six
monthly decisions/year. This is not an exact discrete probability and WTI
month ends are not asserted independent, continuous, rank-uniform, or random.
Q02 owns the actual frequency verdict.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed JFE trading evidence with complete-paper provenance and
  explicit WTI membership; a peer-reviewed JASA method record; and complete
  exact-method files from a CRAN package. The 1982 body and trading
  conjunction are explicitly untested.
- R2 `PASS`: clock, month selection, strict no-tie rank assignment,
  denominator invariant, successive-difference numerator, mean boundary,
  endpoint direction, attempt, risk, stop, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, ranks, integer arithmetic, ATR risk
  controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,669 EA-registry rows, 1,320 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_bartels_rank_tr_preallocation_dedup_20260826.json`,
SHA-256 `03C4061B2DA5BE53933F95FA78DF730BC96FA8D3EE436B5C39D39D0A3152D198`.

Manual functional review fixes a new path statistic rather than a renamed
horizon:

- `QM5_20264_wti-rank-trend` counts the signs of all ordered endpoint pairs;
  this rule squares only twelve successive rank differences.
- `QM5_20274_wti-path-eff` retains price-move magnitudes in a net/path ratio;
  this rule discards magnitude after ordinal ranking and uses a fixed rank
  denominator.
- `QM5_41167_wti-coxstuart-tr` compares seven disjoint lag-seven pairs among
  fourteen endpoints; this rule uses thirteen endpoints and adjacent ranks.
- `QM5_41169_wti-foster-record-tr` counts new running extremes; this rule
  counts neither records nor threshold crossings.
- slope, regression, moving-average, oscillator, calendar, external-series,
  and prior-result gates are absent.
- On ranks `[2,3,10,5,6,12,11,4,1,0,9,8,7]`, zero-based for readability,
  `NM=255<364` and the endpoint rises, so this rule buys; the Mann-Kendall
  score is `4` and the Foster-Stuart record imbalance is `1`, so both named
  neighbors stay flat.
- On ranks `[2,5,7,0,9,3,4,12,1,10,6,8,11]`, `NM=475` and this rule stays
  flat even though the endpoint rises, Mann-Kendall is `28`, and the
  Foster-Stuart imbalance is `3`.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither WTI exposure nor rank-persistence logic.

Verdict: `CLEAN_WTI_MONTHLY_BARTELS_RANK_RVN_LT2_ENDPOINT_TREND`.

## Kill And Safety Boundary

The pre-result density prior is five to eight completed WTI positions per full
post-warm-up year. Q02 must retire the candidate below five completed
positions in any full year, at zero trades, with nonpositive governed
economics, or on any month, endpoint, rank, invariant, numerator, side,
attempt, risk, lifecycle, or determinism defect.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns the overlap verdict. No failed result may be rescued by changing the
sample, rank rule, boundary, direction, risk, hold, or by adding a seasonal,
volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not compile, dispatch, reserve, stop, reap, reprioritize, or
otherwise control a tester.
