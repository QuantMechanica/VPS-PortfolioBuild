# XNG Ten-Year Same-Calendar Huber Seasonality - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its CPU ceiling.
Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It permits a second XNG edge only when its logic
differs from `QM5_12567`, requires structural low-frequency mechanics,
reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate work.

## Candidate Identity

- proposed slug: `xng-samecal-huber10`
- proposed strategy ID: `KELOHARJU-HUBER-XNG-SAMECAL10-2026_S01`
- proposed source ID: `KELOHARJU-HUBER-XNG-SAMECAL10-2026`
- carrier / host: exact `XNGUSD.DWX`, D1, slot 0
- clock: first executable D1 tick after each genuine broker-month transition
- state: exact prior-ten-year XNG returns for the upcoming calendar month
- statistic: fixed-scale 32-update Huber M-location initialized from the even
  median and scaled by the even raw MAD
- lifecycle: follow the strict Huber-location sign until the next month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The complete bounded packet is
`strategy-seeds/sources/KELOHARJU-HUBER-XNG-SAMECAL10-2026/source.md`. Its two
complete-read parent packets and exact hashes are bound by
`artifacts/qm5_xng_samecal_huber10_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, DOI `10.1111/jofi.12398`, supply same-calendar return seasonality,
explicit natural-gas membership, monthly renewal, and a five-year eligibility
floor. Huber (1964), *Annals of Mathematical Statistics* 35(1), 73-101, DOI
`10.1214/aoms/1177703732`, supplies bounded-influence location lineage. The
exact fixed-scale iteration is already governed in the complete
`MOP-WTI-HUBER-2026` packet; no WTI carrier result transfers.

No source tests the exact ten-year same-calendar Huber conjunction, a
standalone continuous XNG CFD, the locked execution plumbing, or the current
book. No performance, significance, density, cost, drawdown, CFD-equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XNGUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair owned exposure and persist `yyyymm` before every fallible entry
   gate. Never retry the month after any downstream outcome.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the exact completed calendar-month log return for month `M` in every year
   `Y-1..Y-10`; require all ten exact years and strict adjacent endpoints.
3. Compute the even median and even raw MAD, freeze
   `delta=1.5*1.4826*MAD`, and run exactly 32 Huber reweighted-mean updates.
4. BUY above `+1e-12`, SELL below `-1e-12`, and consume flat otherwise.
5. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` position with a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 3,000-point positive-spread ceiling.
6. Close at the next broker-month boundary; 35 elapsed days is repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. No
fallback estimator, current-month input, trend confirmation, magnitude
sizing, weather, storage, inventory, event, curve, volume, optimizer artifact,
trained output, or external runtime feed is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_SINGLE_CARRIER_AND_CFD_TRANSLATION_RISK`:
  complete-read peer-reviewed lineage supports the information object,
  natural-gas membership, and bounded-influence arithmetic; the exact
  conjunction is untested.
- R2 `PASS`: exact years, endpoints, median/MAD, constants, weight equation,
  update count, sign band, attempt, risk, stop, spread, and lifecycle are
  locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XNGUSD.DWX` D1 and MT5 state provide all inputs; history,
  label, roll, fill, and CFD-basis risks remain explicit.
- R4 `PASS`: deterministic calendar, logarithm, sort, absolute-deviation,
  fixed arithmetic, ATR-risk, and execution state only; no trained output,
  banned signal indicator, or external feed.

## Non-Duplicate Decision

The canonical checker scanned 4,704 registry identities, 1,350 cards, and all
45 current Strategy Wiki nodes. It found no exact collision and returned the
expected fuzzy WTI-Huber and XNG-raw-mean neighbors. Receipt:
`artifacts/qm5_xng_samecal_huber10_preallocation_dedup_20260829.json`.

Manual review separates the executable identity:

- `QM5_20100` is a raw XNG same-calendar mean with no robust scale or
  iteration;
- `QM5_41204` is the governed statistic on WTI, not XNG; this candidate is an
  explicit carrier port rather than a claim to a new estimator family; and
- `QM5_12567` is a trend-filtered cumulative-RSI2 pullback with a short
  lifecycle, not historical matching-month location with monthly renewal.

The fixed ten-return disagreement vector makes the Huber location negative
while the raw mean and centered signed-rank score are positive. Verdict:
`FUZZY_MATCH_RESOLVED_GOVERNED_XNG_PORT_DISTINCT_FROM_RAW_MEAN_AND_QM5_12567`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate at zero trades, below five completed
positions in any full post-warm-up year, with nonpositive governed economics,
or on any label, endpoint, exact-year, median, MAD, scale, weight, iteration,
side, attempt, risk, stop, lifecycle, or determinism defect. No failed result
may be rescued by changing the sample, estimator, tuning, update count,
direction, risk, hold, spread, retry rules, or any gate.

The monthly seasonal clock is structurally different from the incumbent XNG
pullback, but only unchanged Q09 owns realized decorrelation. This approval
excludes manual backtests; live/demo/shadow/stress/optimization setfiles;
terminal control; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers.
