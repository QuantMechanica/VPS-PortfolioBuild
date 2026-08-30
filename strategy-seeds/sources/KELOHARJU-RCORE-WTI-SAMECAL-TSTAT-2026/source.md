---
source_id: KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026
title: WTI same-calendar seasonality with a one-standard-error gate
publisher: QuantMechanica governed composite of peer-reviewed evidence and commit-pinned primary software
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_wti_same_calendar_tscore_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
strategy_ids: [KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026_S01]
---

# WTI Same-Calendar One-Standard-Error Seasonality Source Packet

## Bounded Source Basis

The durable source decision
`decisions/2026-08-30_wti_same_calendar_tscore_source_approval.md` was
committed as `a2be522599b3e48f87a295af3aa9447e9a3d44d6` before this extraction.
The governed parent packet was read completely. Hash, byte, line, route,
commit, and blob evidence is bound in
`artifacts/qm5_wti_samecal_tstat_source_provenance_20260830.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, monthly renewal,
explicit crude-oil membership, and a minimum five-year history condition.

The commit-pinned R Core `t.test.R` implementation at
`bac583951b728e97b9786804d3b4081f0fe18df5`, blob
`2c1e8d19a3150978e1b56f3ee8985f43a17382f6`, supplies only the exact
one-sample arithmetic precedent: arithmetic mean, sample variance, standard
error `sqrt(variance/n)`, and `t=(mean-mu)/standard_error`. The public file
was routed first through the deterministic source reader and read completely
through the connected GitHub app. Raw source text is not republished.

No source tests this exact conjunction, an absolute WTI score, a strict
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
3. Compute the arithmetic mean, sample variance with denominator `n-1`,
   standard error `sqrt(variance/n)`, and `t=mean/standard_error`. Require
   finite positive variance and standard error.
4. Above `+1.0+1e-10`, buy WTI. Below `-1.0-1e-10`, sell WTI. Equality, the
   inclusive interior band, or invalid state consumes the month flat. Signal
   magnitude never changes size.
5. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` fixed-
   risk budget. Attach a frozen `3.5*ATR(20,D1)` broker hard stop, no target,
   and reject crossed quotes, negative modeled spread, or spread above 1,500
   WTI points.
6. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. Runtime
uses only registered native MT5 D1 OHLC/timestamps, broker time, quotes,
contract metadata, positions, deals, terminal-persistent attempt state, and
V5 framework services. No curve, inventory, storage, weather, volume, open
interest, event feed, API, CSV, p-value table, trained output, banned signal
indicator, or optimizer result is read.

## Exact Statistical Contract

Let `r[0]..r[n-1]`, `5<=n<=10`, be finite exact-year WTI same-calendar log
returns:

```text
mean     = sum(r[i]) / n
variance = sum((r[i]-mean)^2) / (n-1)
se       = sqrt(variance / n)
t        = mean / se

t > +1.0 + 1e-10 => BUY WTI
t < -1.0 - 1e-10 => SELL WTI
otherwise          => FLAT
```

Require finite mean, strictly positive finite variance and standard error,
and finite score. No population variance, unscaled raw mean, trimmed or
Winsorized mean, median, Hodges-Lehmann, Huber location, signed rank, p-value,
critical-value lookup, current-month input, contrarian sign, magnitude sizing,
or fallback estimator is equivalent.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,710 registry identities, 1,356 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced the two
expected fuzzy neighbors. Receipt:
`artifacts/qm5_wti_samecal_tstat_preallocation_dedup_20260830.json`, SHA-256
`DB72E22F089B1BAB6AD22C1C597DC35D4D98AED64E7D8C96DA51550A8D1596BF`.

- `QM5_20099_wti-samecal` follows every nonzero arithmetic mean. This
  candidate scales the same observations by their sample standard error and
  remains flat throughout a strict fixed band.
- `QM5_41191_wti-samecal-srank` uses signed absolute ranks and discards metric
  distance. It has no arithmetic mean, sample standard error, or fixed
  confidence gate.
- `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` use trimmed-mean,
  Hodges-Lehmann, Winsorized-mean, and fixed-scale Huber estimators. None has
  the `n-1` variance / mean-standard-error gate.
- `QM5_41209_wti-seas-resid-mom` follows a standardized just-completed return
  residual in the next month. This packet forecasts the upcoming month from
  its earlier same-calendar return distribution.
- `QM5_41210_xauxag-samecal-tstat` applies the statistic to synchronized
  XAU-minus-XAG returns and owns an opposite-leg metals basket. This packet
  reads and trades only WTI; return orientation, carrier, position topology,
  and realized exposure differ.

For the fixed vector
`[0.020,0.015,0.010,0.005,0.001,-0.040]`, the raw mean is positive while the
one-sample score is inside `[-1,+1]`. The raw-mean sibling buys WTI; this
packet abstains. Sample dispersion and the fixed gate are therefore load
bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_MEAN_STANDARD_ERROR_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Reputable-Source Criteria

- R1 `PASS_WITH_SINGLE_CFD_AND_LOCKED_THRESHOLD_RISK`: complete-read,
  peer-reviewed same-calendar commodity evidence explicitly includes crude
  oil; commit-pinned primary software fixes the statistic. The exact
  conjunction is untested.
- R2 `PASS`: clock, normalized endpoints, exact-year bound, sample floor,
  mean, `n-1` variance, standard error, band, side, attempt, fixed risk, stop,
  spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history and MT5 state provide every
  runtime field; label, history, roll, financing, and CFD-basis risks remain
  explicit.
- R4 `PASS`: timestamps, logarithms, sums, sample variance, square root,
  comparisons, ATR-risk plumbing, and execution state only; no trained
  signal, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Q02 retires on zero positions, fewer than five completed positions in any
full post-warm-up year, nonpositive governed economics, or any calendar,
endpoint, sample, mean, variance, standard-error, score, side, attempt, risk,
stop, spread, lifecycle, or determinism defect. No failed result may be
rescued by changing the sample, threshold, direction, carrier, stop, hold,
spread, retry contract, or adding a fallback.

Direct WTI provides economically different underlying exposure from the
stated XAU/SP500/NDX/XNG book, but it does not prove low factor or portfolio
correlation. Only unchanged Q09 may judge realized overlap. This packet
authorizes one branch-only non-live card/build, strict Q01 validation, and one
paced Q02 enqueue if capacity permits. It excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
