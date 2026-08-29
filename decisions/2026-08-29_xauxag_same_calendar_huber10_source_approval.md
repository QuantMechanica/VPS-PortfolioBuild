# XAU/XAG Ten-Year Same-Calendar Huber Relative Seasonality - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced logical-basket Q02 enqueue if the active factory remains below its
CPU ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly names a market-neutral XAU/XAG basket as an
acceptable route, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-samecal-huber10`
- proposed strategy ID: `KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026_S01`
- proposed source ID: `KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- clock: first executable host D1 tick after each genuine broker-month
  transition
- state: exact ten synchronized prior-year relative returns for the upcoming
  calendar month
- statistic: fixed-scale 32-update Huber M-location initialized from the even
  median and scaled by the even raw MAD
- lifecycle: follow the strict location sign as an opposite-leg XAU/XAG
  package until the next month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The complete bounded packet is
`strategy-seeds/sources/KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026/source.md`,
SHA-256
`1979F66E61B1CA514BD2E89EF75912C4550ABEECEC0C5A98D9D7C476997A22A9`.
Its complete-read parents and exact hashes are bound by
`artifacts/qm5_xauxag_samecal_huber10_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, DOI `10.1111/jofi.12398`, supply same-calendar commodity-return
information, monthly renewal, and a history floor. Fuertes, Miffre, and
Rallis (2010), *Journal of Banking & Finance* 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`, supply the governed XAU/XAG cross-sectional
carrier. Huber (1964), *Annals of Mathematical Statistics* 35(1), 73-101,
DOI `10.1214/aoms/1177703732`, supplies bounded-influence location lineage;
the existing complete governed Huber packet fixes the exact arithmetic.

No source tests the exact paired ten-year same-calendar Huber conjunction, a
Darwinex CFD basket, locked execution plumbing, or the current book. No
performance, significance, density, cost, drawdown, hedge, CFD-equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XAUUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair owned exposure and persist `yyyymm` before every fallible entry
   gate. Never retry the month after any downstream outcome.
2. Under one uniform native or `+1` metal D1-label convention, reconstruct
   synchronized completed XAU and XAG calendar-month log returns for month
   `M` in every exact year `Y-1..Y-10`. Require matching endpoint timestamps,
   strict adjacent months, confirming following bars, and all ten pairs.
3. Form `d=r_xau-r_xag`, compute the even median and even raw MAD, freeze
   `delta=1.5*1.4826*MAD`, and run exactly 32 Huber reweighted-mean updates.
4. Above `+1e-12`, buy XAU and sell XAG; below `-1e-12`, sell XAU and buy XAG;
   consume flat otherwise. Magnitude never changes size.
5. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget equally by per-leg stop risk. Attach
   frozen `3.5*ATR(20,D1)` hard stops and no targets.
6. Reject genuinely positive spreads above 1,500 XAU points or 3,000 XAG
   points. Flatten partial or malformed composition immediately.
7. Close at the next broker-month boundary; 40 elapsed days is survivor
   repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. No
fallback estimator, current-month input, contrarian reversal, magnitude
sizing, curve, inventory, event, volume, optimizer artifact, trained output,
or external runtime feed is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_PAIR_AND_CFD_TRANSLATION_RISK`:
  complete-read peer-reviewed lineage supports the seasonal information,
  governed metal pair, and bounded-influence arithmetic; the exact
  conjunction is untested.
- R2 `PASS`: calendar, synchronization, exact years, relative orientation,
  median/MAD, constants, weights, update count, sign band, attempt, shared
  risk, stops, atomicity, and lifecycle are locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native XAU/XAG D1 histories and MT5 state provide all inputs;
  history, label, roll, legging, fill, and CFD-basis risks remain explicit.
- R4 `PASS`: deterministic dates, logarithms, sorting, absolute deviations,
  fixed arithmetic, ATR-risk controls, and execution state only; no trained
  output, banned signal indicator, or external feed.

## Non-Duplicate Decision

The canonical checker scanned 4,705 registry identities, 1,351 cards, and all
45 current Strategy Wiki nodes. It found no exact collision and returned the
expected fuzzy raw-mean, signed-rank, WTI-Huber, and XNG-Huber neighbors.
Receipt:
`artifacts/qm5_xauxag_samecal_huber10_preallocation_dedup_20260829.json`,
SHA-256
`5EF82AF457CF175BE027E302B1824621876059C6BFB11FC0EC4FA2646D078EC6`.

Manual review separates the executable identity:

- `QM5_20186` uses an arithmetic mean with no robust scale or iteration;
- `QM5_41203` uses a centered signed absolute-rank score and discards metric
  distances;
- `QM5_41204` and `QM5_41205` own standalone WTI and XNG positions rather
  than a synchronized atomic XAU/XAG relative package; and
- existing ratio/residual/recent-window/channel/session baskets observe
  different state objects.

The fixed ten-relative-return disagreement vector makes the Huber location
negative while the raw mean and centered signed-rank score are positive.
Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_EXACT_TEN_YEAR_SAMECAL_FIXED_SCALE_HUBER_RELATIVE_LOCATION_MONTHLY_BASKET`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate at zero trades, below five completed
packages in any full post-warm-up year, with nonpositive governed economics,
or on any label, endpoint, synchronization, exact-year, median, MAD, scale,
weight, iteration, side, attempt, atomicity, fixed-risk, stop, lifecycle, or
determinism defect. No failed result may be rescued by changing the sample,
estimator, tuning, update count, direction, risk, hold, spread, retry rules,
or any gate.

The opposite legs target relative precious-metal seasonality but do not prove
dollar, beta, volatility, or portfolio neutrality. Only unchanged Q09 owns
realized decorrelation. This approval excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
