---
source_id: KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026
title: XAU/XAG same-calendar relative seasonality with a one-standard-error gate
publisher: QuantMechanica governed composite of peer-reviewed sources and commit-pinned primary software
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_xauxag_same_calendar_tscore_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
  - strategy-seeds/sources/FMR-MOMTS-2010/source.md
strategy_ids: [KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026_S01]
---

# XAU/XAG Same-Calendar One-Standard-Error Relative Seasonality Source Packet

## Bounded Source Basis

The durable source decision
`decisions/2026-08-30_xauxag_same_calendar_tscore_source_approval.md` was
committed as `ba45caf7cae7c6501ece24a2967bd37133ca6c1e` before this extraction.
All parent packets were read completely. Hash, byte, line, route, commit, and
blob evidence is bound in
`artifacts/qm5_xauxag_samecal_tstat_source_provenance_20260830.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, monthly renewal, and
a minimum five-year history condition. Fuertes, Miffre, and Rallis (2010),
"Tactical Allocation in Commodity Futures Markets: Combining Momentum and
Term Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548,
DOI `10.1016/j.jbankfin.2010.04.009`, supply the governed XAU/XAG
cross-sectional commodity carrier and one-month long/short translation.

The commit-pinned R Core `t.test.R` implementation at
`bac583951b728e97b9786804d3b4081f0fe18df5`, blob
`2c1e8d19a3150978e1b56f3ee8985f43a17382f6`, supplies only the exact
one-sample arithmetic precedent: arithmetic mean, sample variance, standard
error `sqrt(variance/n)`, and `t=(mean-mu)/standard_error`. The public file
was routed first through the deterministic source reader and read completely
through the connected GitHub API. Raw source text is not republished.

No source tests this exact conjunction, the paired XAU-minus-XAG score, a
strict one-standard-error trading gate, a Darwinex CFD basket, the locked
execution plumbing, or the current portfolio. No source return, alpha,
significance, density, cost, drawdown, hedge, futures/CFD equivalence,
correlation, or portfolio result transfers. The score threshold is a locked
QM falsification choice and not a conventional statistical-significance
claim; the EA never computes a p-value.

## Approved Mechanical Translation

On the first executable `XAUUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair owned basket exposure, then persist the current broker `yyyymm`
   before every fallible entry gate. A flat, blocked, rejected, failed,
   stopped, or restarted month never retries.
2. Under one uniform native or `+1` metal D1-label convention, reconstruct
   synchronized completed XAU and XAG log returns for calendar month `M` in
   exact years `Y-1..Y-10`. Require strict adjacent-month endpoints,
   confirming following bars, and matching endpoint timestamps across both
   legs. Missing older years are skipped without substitution; require at
   least five valid paired observations.
3. Form `d_i=r_xau_i-r_xag_i`. Compute the arithmetic mean, sample variance
   with denominator `n-1`, standard error `sqrt(variance/n)`, and
   `t=mean/standard_error`. Require finite positive variance and standard
   error.
4. Above `+1.0+1e-10`, buy XAU and sell XAG. Below `-1.0-1e-10`, sell XAU
   and buy XAG. Equality, the inclusive interior band, or invalid state
   consumes the month flat. Signal magnitude never changes size.
5. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget into equal fixed-risk halves. Attach
   frozen `3.5*ATR(20,D1)` broker hard stops, no targets, and reject crossed
   quotes, negative modeled spread, or spread above 1,500 XAU points and
   3,000 XAG points.
6. Prepare both legs before submission. If either leg cannot be prepared, the
   second leg fails, or final package composition is malformed, immediately
   flatten every owned leg.
7. Close both legs at the next genuine broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. Runtime
uses only registered MT5 D1 OHLC/timestamps, broker time, quotes, contract
metadata, positions, deals, terminal-persistent attempt state, and V5
framework services. No curve, inventory, volume, open interest, event feed,
API, CSV, p-value table, trained output, banned signal indicator, or optimizer
result is read.

## Exact Statistical Contract

Let `d[0]..d[n-1]`, `5<=n<=10`, be finite synchronized exact-year
same-calendar relative log returns, with `d=r_xau-r_xag`:

```text
mean     = sum(d[i]) / n
variance = sum((d[i]-mean)^2) / (n-1)
se       = sqrt(variance / n)
t        = mean / se

t > +1.0 + 1e-10 => BUY XAU, SELL XAG
t < -1.0 - 1e-10 => SELL XAU, BUY XAG
otherwise          => FLAT
```

Require finite mean, strictly positive finite variance and standard error,
and finite score. No population variance, unscaled raw mean, median, Huber
location, signed rank, p-value, critical-value lookup, current-month input,
contrarian sign, magnitude sizing, or fallback estimator is equivalent.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,709 registry identities, 1,355 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced only the
expected raw same-calendar mean neighbor. Receipt:
`artifacts/qm5_xauxag_samecal_tstat_preallocation_dedup_20260830.json`,
SHA-256
`D53CD7B7F36D978F85F4552DE095C3D357A09B9783E74D4BA3C60E60CE74AB80`.

- `QM5_20186_xauxag-samecal` follows every nonzero arithmetic mean. This
  candidate scales the same paired observations by their sample standard
  error and remains flat throughout a strict fixed band.
- `QM5_41203_xauxag-samecal-srank` uses signed absolute ranks and discards
  metric distance. It has no arithmetic mean, sample standard error, or
  fixed confidence gate.
- `QM5_41206_xauxag-samecal-huber10` follows a fixed-scale iterative robust
  location. It has no `n-1` variance, mean standard error, or strict
  abstention band.
- `QM5_21517_xauxag-seas-rv` fades a just-completed relative surprise. This
  packet forecasts the upcoming month from historical same-calendar relative
  observations and follows only a strong score.
- Ratio z-score, OLS/CADF residual, recent-window momentum, channel, weekday,
  weekend, and correlation-break baskets observe other information objects.

For the fixed vector
`[0.020,0.015,0.010,0.005,0.001,-0.040]`, the raw mean, centered signed-rank
score, and Huber location are positive, while the one-sample score is inside
`[-1,+1]`. The raw, rank, and Huber siblings take long-XAU/short-XAG
exposure; this packet abstains. Sample dispersion and the gate are therefore
load bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_SAMECAL_RELATIVE_MEAN_STANDARD_ERROR_GATE_MONTHLY_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK`:
  complete-read peer-reviewed trading lineages support same-calendar
  commodity information and the governed XAU/XAG carrier; commit-pinned
  primary software fixes the statistic. The exact conjunction is untested.
- R2 `PASS`: host, clock, synchronization, exact-year bound, sample floor,
  relative orientation, mean, `n-1` variance, standard error, band, side,
  attempt, shared risk, stops, atomicity, and lifecycle are deterministic and
  locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5
  state provide every runtime field; label, history, roll, legging, fill, and
  CFD-basis risks remain explicit.
- R4 `PASS`: timestamps, logarithms, sums, sample variance, square root,
  comparisons, ATR-risk plumbing, and execution state only; no trained
  signal, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Q02 retires on zero packages, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any calendar, endpoint,
synchronization, sample, orientation, mean, variance, standard-error, score,
side, attempt, atomicity, risk, stop, lifecycle, or determinism defect. No
failed result may be rescued by changing the sample, threshold, direction,
carrier, stop, hold, spread, retry contract, or adding a fallback.

Opposite metal legs target relative rather than outright precious-metal
returns, but do not prove dollar, beta, volatility, or portfolio neutrality.
Only unchanged Q09 may judge realized overlap. This packet authorizes one
branch-only non-live card/build, strict Q01 validation, and one paced logical-
basket Q02 enqueue if capacity permits. It excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
