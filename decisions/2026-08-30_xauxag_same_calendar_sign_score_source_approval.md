# XAU/XAG Same-Calendar Relative Sign-Score Seasonality - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced logical-basket Q02 enqueue if the active factory remains below its
hard CPU ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly permits a market-neutral XAU/XAG basket,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-samecal-signscore`
- proposed strategy ID:
  `KELOHARJU-PAPAILIAS-RCORE-XAUXAG-SAMECAL-SIGNSCORE-2026_S01`
- proposed source ID:
  `KELOHARJU-PAPAILIAS-RCORE-XAUXAG-SAMECAL-SIGNSCORE-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- clock: first executable host D1 tick after each genuine normalized
  broker-month transition
- state: nonnegative count across up to ten synchronized prior-year
  XAU-minus-XAG relative log returns for the upcoming calendar month, with at
  least five observations
- statistic: signed one-sample Bernoulli score against null probability 0.5
- lifecycle: follow only a relative sign imbalance outside a strict
  one-standard-error band, as an opposite-leg basket, until the next broker
  month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

Extraction may use only these completely read, governed records:

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
4. `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`, SHA-256
   `5EFDB021EE4D1B00A2D7CE356A5EACA85511896C4FD999A5B069B5F936ABA32F`,
   covering Papailias, Liu, and Thomakos (2021), "Return Signal Momentum,"
   *Journal of Banking & Finance* 124, 106063, DOI
   `10.1016/j.jbankfin.2021.106063`, including the complete accepted
   manuscript and appendices.
5. The complete governed sign-score packet
   `strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026/source.md`,
   SHA-256
   `147874FE17B0531E02E49AD5D97910EA47B0CD6F0FA88E2811EEF52B009E9795`,
   and its provenance record
   `artifacts/qm5_wti_samecal_signscore_source_provenance_20260830.json`,
   SHA-256
   `4E82FE44A3DBBFEFFEEB214649E2EC0BB27FF7EED35E31CA13FCDBC267DBB13C`.
   That record binds the complete read of R Core `prop.test.R` at commit
   `9deb2ebef8d0a2fe5cae965697ee4751af857bd1`, blob
   `fc38bd4be1ba8630dbd224162ab5873ae6ac5261`, and the official manual.

Keloharju et al. supply recurring same-calendar commodity-return information,
monthly renewal, and a five-year history floor. Fuertes et al. supply the
governed XAU/XAG cross-sectional commodity carrier and one-month opposite-leg
hold. Papailias et al. supply the deterministic nonnegative-return binary map
and equal weighting of sign observations. Commit-pinned R Core software fixes
the one-sample null at 0.5 and the uncorrected Pearson score arithmetic.

No source tests this exact relative sign-score conjunction, the strict score
band, a two-name Darwinex CFD basket, shared fixed-risk sizing, ATR stops,
spread ceilings, or the current portfolio. No source return, alpha,
significance, profit factor, drawdown, density, cost, hedge, futures/CFD
equivalence, decorrelation, or portfolio result transfers. The locked
`abs(score)>1` rule is a QM falsification threshold, not a conventional
significance claim; runtime never computes a p-value.

## Locked Mechanic

At the first executable `XAUUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure and persist broker `yyyymm` before every fallible
   entry gate. Never retry that month after any downstream outcome.
2. Under one uniform native or `+1` metal D1-label convention, reconstruct
   synchronized completed XAU and XAG log returns for calendar month `M` in
   exact years `Y-1..Y-10`. Require matching endpoint timestamps, strict
   adjacent months, confirming following bars, and at least five valid pairs.
   Missing older years are skipped without replacement; no current-month
   price enters the signal.
3. For every valid year form `d=r_xau-r_xag`. Map `d` to `1` when
   nonnegative and `0` when negative. Let `x` be the nonnegative count and
   `n` the valid paired count.
4. With null `p0=0.5` and no continuity correction, compute the signed score
   `z=(x-n*p0)/sqrt(n*p0*(1-p0))=(2*x-n)/sqrt(n)`. Require integer
   `0<=x<=n`, a finite positive denominator, and a finite score.
5. At `z > +1.0 + 1e-10`, buy XAU and sell XAG. At
   `z < -1.0 - 1e-10`, sell XAU and buy XAG. Equality, the inclusive
   interior band, or invalid state consumes the month flat. Magnitude never
   changes risk.
6. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget into equal fixed-risk halves. Attach
   frozen `3.5*ATR(20,D1)` hard stops and no targets.
7. Reject crossed quotes, negative modeled spread, and genuinely positive
   spread above 1,500 XAU points or 3,000 XAG points. Prepare both legs before
   submission and flatten partial or malformed composition immediately.
8. Close both legs at the next genuine normalized broker-month boundary; 40
   elapsed calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There is
no p-value lookup, continuity correction, magnitude weighting, arithmetic
mean, sample variance, rank weight, median, Huber fallback, current-month
input, contrarian flip, magnitude sizing, ratio z-score, curve, inventory,
event, volume, optimizer artifact, trained output, banned signal indicator,
or external runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATISTIC_PAIR_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`:
  complete-read, DOI-bearing peer-reviewed lineages support the seasonal
  information, binary representation, and governed XAU/XAG carrier;
  commit-pinned primary software fixes the score arithmetic. The exact
  conjunction and threshold remain untested.
- R2 `PASS`: calendar, synchronized endpoints, exact-year bound, sample
  floor, relative orientation, binary map, null, denominator, strict band,
  side, attempt, shared risk, stops, atomicity, and lifecycle are
  deterministic and locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native XAU/XAG D1 histories and MT5 state provide every runtime
  field; history, label, roll, financing, legging, fill, and CFD-basis risks
  remain explicit.
- R4 `PASS`: dates, completed prices, logarithms, integer counts, square
  root, comparisons, ATR-risk controls, and execution state only; no trained
  output, banned signal indicator, or external runtime feed.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,712 registry identities,
1,358 card files, and all 45 current Strategy Wiki nodes. It found no exact
collision and returned the two expected fuzzy neighbors. Receipt:
`artifacts/qm5_xauxag_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`4F4932048D4AE37D7E9ED6CC691FBAEE9CD418030C71B46C60F4A4A1AF765776`.

Manual review fixes the executable boundary:

- `QM5_20186_xauxag-samecal` averages metric XAU-minus-XAG relative returns
  and follows every nonzero mean. This candidate discards magnitude and may
  stay flat inside a sample-size-aware binary-sign band. For relative returns
  `[0.09,-0.01,-0.01,-0.01,-0.01]`, the raw mean is positive and
  `QM5_20186` buys XAU/sells XAG; this candidate has
  `z=-3/sqrt(5)<-1` and sells XAU/buys XAG.
- `QM5_41212_wti-samecal-signscore` supplies the same transparent statistic
  but observes absolute WTI returns, owns one WTI position, and cannot read or
  trade either metal. This candidate observes synchronized XAU-minus-XAG
  relative returns and must own two opposite metal legs under separate
  magics. Changing either leg changes every binary observation and the
  executable package.
- `QM5_41210_xauxag-samecal-tstat` retains return magnitudes and divides their
  arithmetic mean by the sample standard error. For
  `[0.001,0.001,0.001,0.001,-0.100]`, this candidate buys XAU/sells XAG on
  four of five nonnegative signs while the magnitude t-score remains inside
  its flat band.
- `QM5_41203_xauxag-samecal-srank` preserves absolute-rank ordering;
  `QM5_41206_xauxag-samecal-huber10` preserves metric distances through a
  robust location. Neither reduces the sample to an equal-weight Bernoulli
  count or standardizes against fixed null variance.
- Ratio z-score, OLS/CADF residual, recent-window momentum, channel, weekday,
  weekend, and correlation-break baskets observe different state objects.

The relative-return sign map, null variance, sample-size-aware abstention
band, two-metal carrier, and atomic package jointly change direction,
participation, and owned exposure. They are load bearing rather than a slug or
parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_SAMECAL_RELATIVE_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_BASKET`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero packages, fewer than five
completed packages in any full post-warm-up year, nonpositive governed
economics, or any label, endpoint, synchronization, sample, orientation,
binary-map, null, score, threshold, side, attempt, atomicity, fixed-risk,
stop, lifecycle, or determinism defect. A failed result may not be rescued by
changing the sample, threshold, tie map, direction, carrier, stop, hold,
spread, retry rule, or adding a fallback.

Opposite metal legs target relative precious-metal seasonality but do not
prove dollar, beta, volatility, or portfolio neutrality. Only unchanged Q09
owns realized decorrelation. This approval excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
