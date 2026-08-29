---
source_id: KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026
title: XAU/XAG ten-year same-calendar fixed-step Huber relative seasonality
publisher: QuantMechanica governed composite of peer-reviewed sources
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-29
source_approval: decisions/2026-08-29_xauxag_same_calendar_huber10_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md
  - strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md
strategy_ids: [KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026_S01]
---

# XAU/XAG Ten-Year Same-Calendar Huber Relative Seasonality Source Packet

## Bounded Source Basis

Both governed parent packets were read completely before this extraction. The
hash-, byte-, and line-bound read receipt is
`artifacts/qm5_xauxag_samecal_huber10_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, monthly renewal, and
a minimum five-year history condition. Fuertes, Miffre, and Rallis (2010),
"Tactical Allocation in Commodity Futures Markets," *Journal of Banking &
Finance* 34(10), 2530-2548, DOI `10.1016/j.jbankfin.2010.04.009`, supply the
governed XAU/XAG cross-sectional commodity carrier and one-month long/short
translation. The complete composite parent packet binds synchronized paired
month-end reconstruction and the narrow-two-name translation limits.

Huber (1964), "Robust Estimation of a Location Parameter," *The Annals of
Mathematical Statistics* 35(1), 73-101, DOI
`10.1214/aoms/1177703732`, supplies only bounded-influence statistical
lineage. The governed `MOP-WTI-HUBER-2026` packet fixes the exact even
median/MAD scale, `1.4826` normalization, `1.5` tuning constant, weight
equation, and 32 re-centering updates used here. No WTI carrier or trading
result transfers.

No source tests this exact conjunction, the paired XAU-minus-XAG Huber
functional, a Darwinex CFD basket, the locked execution plumbing, or the
current portfolio. No source return, alpha, significance, density, cost,
drawdown, hedge, futures/CFD equivalence, correlation, or portfolio result
transfers.

## Approved Mechanical Translation

On the first executable `XAUUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair owned basket exposure, then persist the current broker `yyyymm`
   before every fallible entry gate. A flat, blocked, rejected, failed,
   stopped, or restarted month never retries.
2. Under one uniform native or `+1` metal D1-label convention, reconstruct
   synchronized completed XAU and XAG log returns for calendar month `M` in
   every exact year `Y-1..Y-10`. Require the prior-month and target-month
   endpoints plus a confirming following bar on both legs, matching endpoint
   timestamps, and all ten exact paired years. Never substitute a nearby or
   current year.
3. Form ten paired relative returns `d=r_xau-r_xag`. Compute the fixed-scale
   Huber location below. A positive final location buys XAU and sells XAG; a
   negative location sells XAU and buys XAG. Consume the month flat inside the
   inclusive `+/-1e-12` band or on any invalid state.
4. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget equally by frozen per-leg stop risk.
   Attach `3.5*ATR(20,D1)` broker hard stops, no targets, and reject genuinely
   positive spreads above 1,500 XAU points or 3,000 XAG points.
5. If either leg cannot be prepared, the second leg fails, or final package
   composition is malformed, immediately flatten every owned leg. Close both
   legs at the next broker-month boundary; 40 elapsed calendar days is
   survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. Runtime
uses only registered MT5 D1 OHLC/timestamps, broker time, quotes, contract
metadata, positions, deals, terminal-persistent attempt state, and V5
framework services. No curve, inventory, volume, open interest, event feed,
API, CSV, trained output, or optimizer result is read.

## Exact Statistical Contract

Let `d[0]..d[9]` be the ten finite synchronized exact-year same-calendar
relative log returns, with `d=r_xau-r_xag`. The year order is retained for
audit but does not affect the symmetric estimator:

```text
s     = ascending copy of d
m     = (s[4] + s[5]) / 2
a[i]  = abs(d[i] - m)
u     = ascending copy of a
MAD   = (u[4] + u[5]) / 2
scale = 1.4826 * MAD
delta = 1.5 * scale

mu[0] = m
for j = 0..31:
  residual = abs(d[i] - mu[j])
  w[i] = 1                         if residual <= delta
         delta / residual          otherwise
  mu[j+1] = sum(w[i] * d[i]) / sum(w[i])

mu[32] > +1e-12 => BUY XAU, SELL XAG
mu[32] < -1e-12 => SELL XAU, BUY XAG
otherwise       => FLAT
```

Require positive finite price endpoints, ten finite relative returns,
strictly positive finite `MAD`, `scale`, `delta`, weights, denominator, and
every iteration state. The scale freezes before iteration and all 32 updates
run. There is no early convergence exit, alternate tuning, fallback mean or
median, year deletion, Winsorization, trimming, signed-rank test,
current-month input, contrarian reversal, or magnitude sizing.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,705 registry identities, 1,351 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced four
expected fuzzy neighbors. Receipt:
`artifacts/qm5_xauxag_samecal_huber10_preallocation_dedup_20260829.json`,
SHA-256 `5EF82AF457CF175BE027E302B1824621876059C6BFB11FC0EC4FA2646D078EC6`.

- `QM5_20186_xauxag-samecal` takes the arithmetic mean of the same paired
  observations. It has no robust scale, bounded residual weights, or
  iterative re-centering.
- `QM5_41203_xauxag-samecal-srank` ranks signed absolute relative returns. It
  discards metric distances and has no location or scale iteration.
- `QM5_41204_wti-samecal-huber10` and
  `QM5_41205_xng-samecal-huber10` use the same governed statistic and clock
  on standalone energy carriers. This candidate instead reconstructs a
  synchronized cross-metal relative return and owns an atomic opposite-leg
  package.
- Ratio z-score, OLS/CADF residual, recent-window rank/change, channel,
  weekday, weekend, and contiguous-momentum baskets observe other information
  objects or state functionals.

For the fixed relative-return vector
`[.0188,-.0148,.0122,.0021,-.0084,-.0013,.0012,.0006,.0058,-.0160]`,
the locked Huber location is approximately `-0.0003122567` and sells XAU /
buys XAG, while the raw mean is `+0.00002` and the centered strict signed-rank
score is `+3`; both neighbors buy XAU / sell XAG. The paired sample, scale,
weights, updates, and package direction are load bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_EXACT_TEN_YEAR_SAMECAL_FIXED_SCALE_HUBER_RELATIVE_LOCATION_MONTHLY_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_PAIR_AND_CFD_TRANSLATION_RISK`:
  complete-read, DOI-bearing peer-reviewed lineage supports same-calendar
  commodity information, the governed XAU/XAG long/short carrier, and
  bounded-influence arithmetic. The exact conjunction remains untested.
- R2 `PASS`: host, clock, synchronized endpoints, exact years, relative
  orientation, even median/MAD, constants, weights, update count, sign band,
  attempt, shared risk, stops, atomicity, and lifecycle are deterministic and
  locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5
  state provide every runtime field; ten-year warm-up, label, roll, legging,
  and CFD-basis risks remain explicit.
- R4 `PASS`: timestamps, logarithms, sorting, absolute deviations, fixed
  arithmetic, ATR risk plumbing, and execution state only; no trained signal,
  banned indicator, external feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Q02 retires on zero trades, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any calendar, endpoint,
synchronization, exact-year, median, MAD, scale, weight, iteration, side,
attempt, atomicity, risk, stop, lifecycle, or determinism defect. No failed
result may be rescued by changing the sample, estimator, tuning, update count,
direction, carrier, stop, hold, spread, or retry contract.

Opposite metal legs target relative rather than outright precious-metal
returns, but do not prove dollar, beta, volatility, or portfolio neutrality.
Only unchanged Q09 may judge realized overlap. This packet authorizes one
branch-only non-live card/build, strict Q01 validation, and one paced logical-
basket Q02 enqueue if capacity permits. It excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
