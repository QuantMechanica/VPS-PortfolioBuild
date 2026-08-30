---
source_id: KELOHARJU-PAPAILIAS-RCORE-XAUXAG-SAMECAL-SIGNSCORE-2026
title: XAU/XAG same-calendar relative seasonality with a Bernoulli sign-score gate
publisher: QuantMechanica governed composite of peer-reviewed evidence and commit-pinned primary software
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_xauxag_same_calendar_sign_score_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
  - strategy-seeds/sources/FMR-MOMTS-2010/source.md
  - strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md
strategy_ids: [KELOHARJU-PAPAILIAS-RCORE-XAUXAG-SAMECAL-SIGNSCORE-2026_S01]
---

# XAU/XAG Same-Calendar Relative Bernoulli Sign-Score Source Packet

## Bounded Source Basis

The durable source decision
`decisions/2026-08-30_xauxag_same_calendar_sign_score_source_approval.md`
was committed as `3d992f08934f929ddc7883d68beb22b68acc8708` before this
extraction. Every governed parent packet was read completely. Hash, byte,
line, commit, route, and blob evidence is bound in
`artifacts/qm5_xauxag_samecal_signscore_source_provenance_20260830.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, monthly renewal,
and a minimum five-year history condition.

Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in Commodity
Futures Markets," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`, supply the governed XAU/XAG
cross-sectional commodity carrier and one-month opposite-leg hold.

Papailias, Liu, and Thomakos (2021), "Return Signal Momentum," *Journal of
Banking & Finance* 124, 106063, DOI
`10.1016/j.jbankfin.2021.106063`, supply the deterministic nonnegative-return
binary representation, equal weighting of sign observations, and monthly
decision and holding clock.

The commit-pinned R Core `prop.test.R` implementation at
`9deb2ebef8d0a2fe5cae965697ee4751af857bd1`, blob
`fc38bd4be1ba8630dbd224162ab5873ae6ac5261`, supplies only the one-sample
proportion-score arithmetic: default null probability 0.5, success and
failure counts, expected counts under the null, and the uncorrected Pearson
score statistic. Its complete-read route and official-manual evidence are
inherited transparently from the governed sign-score provenance record; raw
public source text is not republished.

No source tests this exact conjunction, a two-metal relative sign score, a
strict one-standard-error trading gate, Darwinex continuous CFDs, the locked
execution plumbing, or the current portfolio. No source return, alpha,
significance, density, profit factor, cost, drawdown, hedge, futures/CFD
equivalence, correlation, or portfolio result transfers. The score threshold
is a locked QM falsification choice and not a conventional statistical-
significance claim; the EA never computes a p-value.

## Approved Mechanical Translation

On the first executable `XAUUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure, then persist current broker `yyyymm` before every
   fallible entry gate. A flat, blocked, rejected, failed, stopped, or
   restarted month never retries.
2. Under one uniform native or `+1` metal D1-label convention, reconstruct
   synchronized completed XAU and XAG log returns for calendar month `M` in
   exact years `Y-1..Y-10`. Require strict adjacent-month endpoints,
   confirming following bars, and timestamp identity across both legs.
   Missing older years are skipped without substitution; require at least
   five valid pairs.
3. For every pair form `d=r_xau-r_xag`. Map every finite `d` to one when
   nonnegative and zero when negative. Let `x` be the nonnegative count and
   `n` the valid paired count.
4. Against fixed null probability `p0=0.5`, with no continuity correction,
   compute the signed score
   `z=(x-n*p0)/sqrt(n*p0*(1-p0))=(2*x-n)/sqrt(n)`.
5. Above `+1.0+1e-10`, buy XAU and sell XAG. Below `-1.0-1e-10`, sell XAU
   and buy XAG. Equality, the inclusive interior band, or invalid state
   consumes the month flat. Signal magnitude never changes size.
6. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget into equal fixed-risk halves. Attach
   frozen `3.5*ATR(20,D1)` broker hard stops, no targets, and reject crossed
   quotes, negative modeled spread, or spread above 1,500 XAU points or
   3,000 XAG points.
7. Prepare both orders before opening and flatten every owned leg immediately
   after partial submission, wrong composition, or malformed state.
8. Close both legs at the next genuine normalized broker-month boundary; 40
   elapsed calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. Runtime
uses only registered native MT5 D1 OHLC/timestamps, broker time, quotes,
contract metadata, positions, deals, terminal-persistent attempt state, and
V5 framework services. No ratio z-score, curve, inventory, storage, weather,
volume, open interest, event feed, API, CSV, p-value table, trained output,
banned signal indicator, or optimizer result is read.

## Exact Statistical Contract

Let `d[0]..d[n-1]`, `5<=n<=10`, be finite synchronized exact-year
XAU-minus-XAG same-calendar relative log returns and
`x=sum(1[d[i]>=0])`:

```text
p0          = 0.5
denominator = sqrt(n * p0 * (1-p0)) = 0.5*sqrt(n)
score       = (x - n*p0) / denominator = (2*x-n)/sqrt(n)

score > +1.0 + 1e-10 => BUY XAU, SELL XAG
score < -1.0 - 1e-10 => SELL XAU, BUY XAG
otherwise              => FLAT
```

Require integer `0<=x<=n`, matching completed endpoints, a finite positive
denominator, and a finite score. No continuity correction, exact-binomial
p-value, chi-squared lookup, return magnitude, arithmetic mean, sample
variance, median, rank weight, robust location, current-month data,
contrarian sign, magnitude sizing, or fallback estimator is equivalent.

R Core's uncorrected one-sample Pearson statistic at `p0=0.5` is
`X2=(x-n/2)^2/(n/2)+((n-x)-n/2)^2/(n/2)=(2*x-n)^2/n`. The locked signed
score is `sign(x/n-p0)*sqrt(X2)`, which reduces to the expression above.
Runtime implements the reduced arithmetic directly and does not invoke R.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,712 registry identities, 1,358 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced the two
expected fuzzy neighbors. Receipt:
`artifacts/qm5_xauxag_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`4F4932048D4AE37D7E9ED6CC691FBAEE9CD418030C71B46C60F4A4A1AF765776`.

- `QM5_20186_xauxag-samecal` follows the arithmetic mean of metric relative
  returns and normally chooses a side. This packet discards magnitude and
  stays flat inside a sample-size-aware binary-sign band. For
  `[0.09,-0.01,-0.01,-0.01,-0.01]`, the raw mean buys XAU while this score
  sells XAU.
- `QM5_41212_wti-samecal-signscore` applies the statistic to absolute WTI
  returns and owns one WTI position. This packet observes synchronized
  XAU-minus-XAG returns and requires an atomic two-magic opposite-leg basket.
- `QM5_41210_xauxag-samecal-tstat` standardizes a metric arithmetic mean by
  its sample standard error. For
  `[0.001,0.001,0.001,0.001,-0.100]`, this packet buys XAU on four of five
  nonnegative signs while the magnitude t-score remains flat.
- `QM5_41203_xauxag-samecal-srank` preserves absolute-rank ordering and
  `QM5_41206_xauxag-samecal-huber10` preserves metric distance. Neither
  reduces the sample to an equal-weight Bernoulli count against null
  variance.
- Ratio z-score, OLS/CADF residual, recent-window momentum, channel, session,
  and correlation-break baskets use different information objects.

The relative binary information object, null variance, sample-size-aware
score, symmetric abstention band, two-metal carrier, and atomic lifecycle
jointly change direction, participation, and exposure. They are load bearing
rather than a parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_SAMECAL_RELATIVE_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATISTIC_PAIR_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`:
  complete-read peer-reviewed same-calendar, return-sign, and XAU/XAG
  cross-sectional evidence plus commit-pinned primary software fix the
  information object and arithmetic. The exact conjunction and threshold are
  untested.
- R2 `PASS`: clock, normalized synchronized endpoints, exact-year bound,
  sample floor, relative orientation, binary map, null, denominator, strict
  score band, side, attempt, shared risk, stops, atomicity, and lifecycle are
  deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native XAU/XAG D1 histories and MT5 state provide every runtime
  field; label, history, roll, financing, fill, legging, and CFD-basis risks
  remain explicit.
- R4 `PASS`: timestamps, logarithms, integer counts, square root,
  comparisons, ATR-risk plumbing, and execution state only; no trained
  signal, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Q02 retires on zero packages, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any calendar, endpoint,
synchronization, sample, relative orientation, sign map, null, denominator,
score, side, attempt, risk, stop, spread, atomicity, lifecycle, or determinism
defect. No failed result may be rescued by changing the sample, threshold,
tie map, direction, carrier, stop, hold, spread, retry contract, or adding a
fallback.

The opposite metal legs target relative precious-metal seasonality but do not
prove dollar, beta, volatility, or portfolio neutrality. Only unchanged Q09
may judge realized overlap. This packet authorizes one branch-only non-live
card/build, strict Q01 validation, and one paced logical-basket Q02 enqueue if
capacity permits. It excludes manual backtests; live/demo/shadow/stress/
optimization setfiles; terminal control; AutoTrading; `T_Live`; deploy or
live manifests; portfolio-gate changes; portfolio admission; and correlation
waivers.
