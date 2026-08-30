---
source_id: KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026
title: WTI same-calendar seasonality with a Bernoulli sign-score gate
publisher: QuantMechanica governed composite of peer-reviewed evidence and commit-pinned primary software
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_wti_same_calendar_sign_score_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
  - strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md
strategy_ids: [KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026_S01]
---

# WTI Same-Calendar Bernoulli Sign-Score Source Packet

## Bounded Source Basis

The durable source decision
`decisions/2026-08-30_wti_same_calendar_sign_score_source_approval.md` was
committed as `34edd1f6e1d39c6721f4b1e9aff63c24e2b7ca4f` before this
extraction. Both governed parent packets were read completely. Hash, byte,
line, route, commit, and blob evidence is bound in
`artifacts/qm5_wti_samecal_signscore_source_provenance_20260830.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, monthly renewal,
explicit crude-oil membership, and a minimum five-year history condition.

Papailias, Liu, and Thomakos (2021), "Return Signal Momentum," *Journal of
Banking & Finance* 124, 106063, DOI `10.1016/j.jbankfin.2021.106063`, supply
the deterministic return-sign representation, equal weighting of binary
observations, explicit WTI membership, and a monthly decision and holding
clock.

The commit-pinned R Core `prop.test.R` implementation at
`9deb2ebef8d0a2fe5cae965697ee4751af857bd1`, blob
`fc38bd4be1ba8630dbd224162ab5873ae6ac5261`, supplies only the one-sample
proportion-score arithmetic: default null probability 0.5, success and
failure counts, expected counts under the null, and the uncorrected Pearson
score statistic. The public file and official R manual were read completely;
raw source text is not republished.

No source tests this exact conjunction, an absolute WTI sign score, a strict
one-standard-error trading gate, a Darwinex continuous CFD, the locked
execution plumbing, or the current portfolio. No source return, alpha,
significance, density, profit factor, cost, drawdown, futures/CFD equivalence,
correlation, or portfolio result transfers. The score threshold is a locked
QM falsification choice and not a conventional statistical-significance
claim; the EA never computes a p-value.

## Approved Mechanical Translation

On the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure, then persist current broker `yyyymm` before every
   fallible entry gate. A flat, blocked, rejected, failed, stopped, or
   restarted month never retries.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   completed WTI log returns for calendar month `M` in exact years
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. Missing older years are skipped without substitution;
   require at least five valid observations.
3. Map every finite return to one when nonnegative and zero when negative.
   Let `x` be the nonnegative count and `n` the valid observation count.
4. Against fixed null probability `p0=0.5`, with no continuity correction,
   compute the signed score
   `z=(x-n*p0)/sqrt(n*p0*(1-p0))=(2*x-n)/sqrt(n)`.
5. Above `+1.0+1e-10`, buy WTI. Below `-1.0-1e-10`, sell WTI. Equality, the
   inclusive interior band, or invalid state consumes the month flat. Signal
   magnitude never changes size.
6. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` fixed-
   risk budget. Attach a frozen `3.5*ATR(20,D1)` broker hard stop, no target,
   and reject crossed quotes, negative modeled spread, or spread above 1,500
   WTI points.
7. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. Runtime
uses only registered native MT5 D1 OHLC/timestamps, broker time, quotes,
contract metadata, positions, deals, terminal-persistent attempt state, and
V5 framework services. No curve, inventory, storage, weather, volume, open
interest, event feed, API, CSV, p-value table, trained output, banned signal
indicator, or optimizer result is read.

## Exact Statistical Contract

Let `r[0]..r[n-1]`, `5<=n<=10`, be finite exact-year WTI same-calendar log
returns and `x=sum(1[r[i]>=0])`:

```text
p0          = 0.5
denominator = sqrt(n * p0 * (1-p0)) = 0.5*sqrt(n)
score       = (x - n*p0) / denominator = (2*x-n)/sqrt(n)

score > +1.0 + 1e-10 => BUY WTI
score < -1.0 - 1e-10 => SELL WTI
otherwise              => FLAT
```

Require integer `0<=x<=n`, finite positive denominator, and finite score. No
continuity correction, exact-binomial p-value, chi-squared lookup, return
magnitude, arithmetic mean, sample variance, median, rank weight, robust
location, current-month input, contrarian sign, magnitude sizing, or fallback
estimator is equivalent.

R Core's uncorrected one-sample Pearson statistic at `p0=0.5` is
`X2=(x-n/2)^2/(n/2)+((n-x)-n/2)^2/(n/2)=(2*x-n)^2/n`. The locked signed
score is `sign(x/n-p0)*sqrt(X2)`, which reduces to the expression above.
Runtime implements the reduced arithmetic directly and does not invoke R.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,711 registry identities, 1,357 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced one
expected fuzzy neighbor. Receipt:
`artifacts/qm5_wti_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`2DDE757731CADAA6E29949741C2E7E9075E59764F402022BF435B7EBC592EBD6`.

- `QM5_20099_wti-samecal` follows the arithmetic mean of return magnitudes
  and normally chooses a side. This packet discards magnitude and stays flat
  inside a sample-size-aware binary-sign band. For
  `[0.09,-0.01,-0.01,-0.01,-0.01]`, the raw mean buys while this score sells.
- `QM5_41059_wti-samecal-hit` uses the same nonnegative binary map but buys
  at frequency `>=0.40` and sells otherwise. It has no symmetric abstention
  band or null-variance standardization. With three successes in six trials
  it buys while this packet has score zero and stays flat.
- `QM5_41191`, `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` use
  signed ranks or robust metric-location estimators. None reduces the sample
  to an unweighted Bernoulli count and standardizes by null variance.
- `QM5_41209_wti-seas-resid-mom` standardizes the just-completed WTI return
  against earlier occurrences of that completed month and follows the
  residual in the next month. This packet forecasts the upcoming month from
  earlier same-calendar signs.
- `QM5_41211_wti-samecal-tstat` standardizes a magnitude mean by its sample
  standard error. For `[0.001,0.001,0.001,0.001,-0.100]`, this packet buys
  on four of five nonnegative signs while the magnitude t-score is flat.

The binary information object, null variance, sample-size-aware score, and
symmetric abstention band jointly change both direction and participation.
They are load bearing rather than a parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_AND_SMALL_SAMPLE_RISK`: complete-read,
  peer-reviewed same-calendar commodity evidence explicitly includes crude
  oil; peer-reviewed return-sign evidence explicitly includes WTI; commit-
  pinned primary software fixes the score arithmetic. The exact conjunction
  and fixed threshold are untested.
- R2 `PASS`: clock, normalized endpoints, exact-year bound, sample floor,
  binary map, null, denominator, strict score band, side, attempt, fixed risk,
  stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history and MT5 state provide every
  runtime field; label, history, roll, financing, and CFD-basis risks remain
  explicit.
- R4 `PASS`: timestamps, logarithms, integer counts, square root,
  comparisons, ATR-risk plumbing, and execution state only; no trained
  signal, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Q02 retires on zero positions, fewer than five completed positions in any
full post-warm-up year, nonpositive governed economics, or any calendar,
endpoint, sample, sign-map, null, denominator, score, side, attempt, risk,
stop, spread, lifecycle, or determinism defect. No failed result may be
rescued by changing the sample, threshold, tie map, direction, carrier, stop,
hold, spread, retry contract, or adding a fallback.

Direct WTI provides economically different underlying exposure from the
stated XAU/SP500/NDX/XNG book, but it does not prove low factor or portfolio
correlation. Only unchanged Q09 may judge realized overlap. This packet
authorizes one branch-only non-live card/build, strict Q01 validation, and one
paced Q02 enqueue if capacity permits. It excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
