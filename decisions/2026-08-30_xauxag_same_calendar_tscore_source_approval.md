# XAU/XAG Same-Calendar One-Standard-Error Relative Seasonality - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced logical-basket Q02 enqueue if the active factory remains below its
hard CPU ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly names a market-neutral XAU/XAG basket as an
acceptable route, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-samecal-tstat`
- proposed strategy ID:
  `KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026_S01`
- proposed source ID: `KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- clock: first executable host D1 tick after each genuine broker-month
  transition
- state: up to ten synchronized prior-year XAU-minus-XAG relative log returns
  for the upcoming calendar month, with at least five pairs
- statistic: arithmetic mean divided by its sample standard error
- lifecycle: follow the relative seasonal sign only outside a strict
  one-standard-error band, as an opposite-leg XAU/XAG package, until the next
  month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

Extraction may use only these completely read governed records:

1. `strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md`,
   SHA-256
   `9266E47C7F3235D900C9432FEAC33A417807AE1E2CC9685FF2FEADAB46DBF75E`,
   the approved composite joining same-calendar commodity information to the
   XAU/XAG monthly cross-sectional carrier.
2. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   covering Keloharju, Linnainmaa, and Nyberg (2016), "Return
   Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, including the complete 57-page NBER review.
3. `strategy-seeds/sources/FMR-MOMTS-2010/source.md`, SHA-256
   `1F4F4977B0D9646A8BF56543D1881CCBC1513D4644DE72C350614580F3FF7417`,
   covering Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in
   Commodity Futures Markets," *Journal of Banking & Finance* 34(10),
   2530-2548, DOI `10.1016/j.jbankfin.2010.04.009`, including the complete
   47-page accepted-manuscript review.
4. Commit-pinned R Core primary software
   `src/library/stats/R/t.test.R` at
   `bac583951b728e97b9786804d3b4081f0fe18df5`, blob
   `2c1e8d19a3150978e1b56f3ee8985f43a17382f6`, read completely through the
   deterministic GitHub route recorded in
   `artifacts/qm5_xauxag_samecal_tstat_source_route_20260830.json`.

Keloharju et al. supply recurring same-calendar commodity-return information,
monthly renewal, and a five-year history floor. Fuertes et al. supply the
governed XAU/XAG cross-sectional carrier and one-month opposite-leg hold. The
R Core source fixes only the transparent one-sample arithmetic:
`sample_variance`, `standard_error=sqrt(sample_variance/n)`, and
`t=(mean-0)/standard_error`.

No source tests this exact two-name, confidence-gated Darwinex CFD basket, the
strict threshold, fixed-risk sizing, ATR stops, spread ceilings, or the
current portfolio. No source profit factor, return, significance, drawdown,
density, cost, hedge, futures/CFD equivalence, decorrelation, or portfolio
result transfers. The locked `abs(t)>1` rule is a QM falsification threshold,
not a conventional-significance or source-performance claim; runtime never
computes a p-value.

## Locked Mechanic

At the first executable `XAUUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair owned exposure and persist broker `yyyymm` before every fallible
   entry gate. Never retry that month after any downstream outcome.
2. Under one uniform native or `+1` metal D1-label convention, reconstruct
   synchronized completed XAU and XAG log returns for calendar month `M` in
   exact years `Y-1..Y-10`. Require matching endpoint timestamps, strict
   adjacent months, confirming following bars, and at least five valid pairs.
   Missing older years are skipped without replacement; no current-month
   price enters the signal.
3. For each valid year form `d=r_xau-r_xag`. Compute
   `mean=sum(d)/n`, sample variance with denominator `n-1`,
   `se=sqrt(variance/n)`, and `t=mean/se`. Require finite positive variance
   and standard error.
4. At `t > +1.0 + 1e-10`, buy XAU and sell XAG. At
   `t < -1.0 - 1e-10`, sell XAU and buy XAG. Equality, the interior band,
   or invalid state consumes the month flat. Magnitude never changes risk.
5. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget into equal fixed-risk halves. Attach
   frozen `3.5*ATR(20,D1)` hard stops and no targets.
6. Reject crossed quotes, negative modeled spread, and genuinely positive
   spread above 1,500 XAU points or 3,000 XAG points. Prepare both legs before
   submission and flatten partial or malformed composition immediately.
7. Close both legs at the next genuine broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There is
no p-value lookup, distribution table, fallback mean-only entry, rank or Huber
fallback, current-month input, contrarian flip, magnitude sizing, curve,
inventory, event, volume, optimizer artifact, trained output, banned signal
indicator, or external runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK`:
  complete-read, DOI-bearing peer-reviewed trading lineages support the
  seasonal information and governed XAU/XAG carrier; commit-pinned primary
  software fixes the statistic. The exact conjunction and threshold remain
  untested.
- R2 `PASS`: calendar, synchronized endpoints, exact-year bound, sample
  floor, relative orientation, mean, `n-1` variance, standard error, strict
  score band, side, attempt, shared risk, stops, atomicity, and lifecycle are
  deterministic and locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native XAU/XAG D1 histories and MT5 state provide every runtime
  field; history, label, roll, financing, legging, fill, and CFD-basis risks
  remain explicit.
- R4 `PASS`: dates, completed prices, logarithms, sums, sample variance,
  square root, comparisons, ATR-risk controls, and execution state only; no
  trained output, banned signal indicator, or external runtime feed.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,709 registry identities,
1,355 card files, and all 45 current Strategy Wiki nodes. It found no exact
collision and returned one expected fuzzy neighbor:
`QM5_20186_xauxag-samecal`. Receipt:
`artifacts/qm5_xauxag_samecal_tstat_preallocation_dedup_20260830.json`,
SHA-256
`D53CD7B7F36D978F85F4552DE095C3D357A09B9783E74D4BA3C60E60CE74AB80`.

Manual review fixes the executable boundary:

- `QM5_20186` follows every nonzero raw arithmetic-mean relative seasonal
  score. This candidate divides that mean by its sample standard error and
  abstains throughout the inclusive one-standard-error band.
- `QM5_41203` converts paired observations to strict signed absolute ranks,
  discards metric distances, and has no sample standard error or fixed
  confidence band.
- `QM5_41206` follows a fixed-scale iterative Huber location and has neither
  `n-1` sample variance nor a mean-standard-error abstention gate.
- `QM5_21517` fades the just-completed relative return after subtracting its
  same-calendar expectation; this candidate forecasts the upcoming month
  from historical same-calendar relative returns and follows rather than
  fades their strong score.
- Ratio z-score, OLS/CADF residual, recent-window momentum, channel, weekday,
  weekend, and correlation-break baskets observe different state objects.

For the fixed relative-return vector
`[0.020,0.015,0.010,0.005,0.001,-0.040]`, the raw mean is positive, so
`QM5_20186` buys XAU/sells XAG; the signed-rank score is positive and the
Huber location remains positive. The locked t score is inside `[-1,+1]`, so
this candidate stays flat. The sample dispersion and abstention band are
therefore load bearing, not a parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_SAMECAL_RELATIVE_MEAN_STANDARD_ERROR_GATE_MONTHLY_BASKET`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero packages, fewer than five
completed packages in any full post-warm-up year, nonpositive governed
economics, or any label, endpoint, synchronization, sample, orientation,
mean, variance, standard-error, score, threshold, side, attempt, atomicity,
fixed-risk, stop, lifecycle, or determinism defect. A failed result may not be
rescued by changing the sample, threshold, direction, carrier, stop, hold,
spread, or retry rule.

Opposite metal legs target relative precious-metal seasonality but do not
prove dollar, beta, volatility, or portfolio neutrality. Only unchanged Q09
owns realized decorrelation. This approval excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
