---
source_id: KELOHARJU-HUBER-WTI-SAMECAL10-2026
title: WTI ten-year same-calendar fixed-step Huber seasonality
publisher: QuantMechanica governed composite of peer-reviewed sources
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-29
source_approval: decisions/2026-08-29_wti_same_calendar_huber10_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
  - strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md
strategy_ids: [KELOHARJU-HUBER-WTI-SAMECAL10-2026_S01]
---

# WTI Ten-Year Same-Calendar Huber Seasonality Source Packet

## Bounded Source Basis

Both governed parent packets were read completely before this extraction. The
hash-, byte-, and line-bound read receipt is
`artifacts/qm5_wti_samecal_huber10_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month return information object, monthly renewal, a minimum
five-year history condition, and explicit crude-oil membership in the
commodity universe. The complete open NBER version is bound by the parent
packet. Their portfolio ranks a broad futures cross-section; it does not test
a single WTI time-series sign or a robust location estimator.

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supply peer-reviewed WTI own-return and
monthly-renewal lineage. Huber (1964), "Robust Estimation of a Location
Parameter," *The Annals of Mathematical Statistics* 35(1), 73-101, DOI
`10.1214/aoms/1177703732`, supplies only the bounded-influence statistical
family. The governed `MOP-WTI-HUBER-2026` packet fixes the median/MAD scale,
`1.4826` normalization, `1.5` tuning constant, weight equation, and exactly
32 re-centering updates.

No source tests the exact conjunction below, a standalone continuous WTI CFD,
the exact ten-year same-calendar sample, the execution plumbing, or the
current portfolio. No source return, alpha, significance, density, cost,
drawdown, futures/CFD equivalence, correlation, or portfolio result transfers.

## Approved Mechanical Translation

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair owned exposure, then persist the current broker `yyyymm` before
   every fallible entry gate. A flat, blocked, rejected, failed, stopped, or
   restarted month never retries.
2. Use one uniform native or `+1` energy D1-label convention. For every exact
   year `Y-k`, `k=1..10`, reconstruct the completed log return for calendar
   month `M` from the immediately preceding month's final D1 close to the
   target month's final D1 close, confirmed by a following D1 bar in the next
   calendar month. Require all ten exact years; never substitute a nearby or
   current year.
3. Compute the fixed-scale Huber location below. BUY above `+1e-12`, SELL
   below `-1e-12`, and consume the month flat inside the inclusive band or on
   any invalid state.
4. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` position with a frozen `3.5*ATR(20,D1)` broker hard
   stop, no target, and a 1,500-point genuinely-positive spread ceiling.
5. Close at the next broker-month boundary; 35 elapsed calendar days is
   survivor repair only.

Both news axes, the legacy news mode, and framework Friday close are OFF.
Runtime uses only registered MT5 D1 OHLC/timestamps, broker time, quotes,
contract metadata, positions, deals, terminal-global attempt state, and V5
framework services. No curve, inventory, volume, open interest, event feed,
API, CSV, trained output, or optimizer result is read.

## Exact Statistical Contract

Let `r[0]..r[9]` be the ten finite exact-year same-calendar log returns. The
year order is irrelevant to the symmetric estimator but must be retained for
audit. Define:

```text
s     = ascending copy of r
m     = (s[4] + s[5]) / 2
d[i]  = abs(r[i] - m)
a     = ascending copy of d
MAD   = (a[4] + a[5]) / 2
scale = 1.4826 * MAD
delta = 1.5 * scale

mu[0] = m
for j = 0..31:
  residual = abs(r[i] - mu[j])
  w[i] = 1                         if residual <= delta
         delta / residual          otherwise
  mu[j+1] = sum(w[i] * r[i]) / sum(w[i])

BUY  iff mu[32] > +1e-12
SELL iff mu[32] < -1e-12
FLAT otherwise
```

Require positive finite price endpoints, ten finite returns, strictly
positive finite `MAD`, `scale`, `delta`, weights, denominator, and every
iteration state. The scale freezes before iteration and all 32 updates run.
There is no early convergence exit, alternate tuning, fallback mean or
median, year deletion, winsorization, trim, signed-rank significance test,
current-month input, or magnitude sizing.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,703 registry identities, 1,349 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced only the
expected raw-mean same-calendar neighbor. Receipt:
`artifacts/qm5_wti_samecal_huber10_preallocation_dedup_20260829.json`.

- `QM5_20099_wti-samecal` averages available prior same-calendar WTI returns.
  It has no median/MAD scale, bounded residual weights, or re-centering.
- `QM5_20285_wti-huber-mom` applies the same governed Huber family to twelve
  adjacent returns from the immediately preceding twelve broker months. This
  candidate instead observes ten disjoint returns for one recurring calendar
  month in exact years `Y-1..Y-10`.
- `QM5_41191_wti-samecal-srank` ranks absolute same-calendar returns and
  centers their positive-rank sum. It does not estimate a return location.
- `QM5_41199`, `QM5_41201`, and `QM5_41202` use exact five-year samples and,
  respectively, a middle-three trim, fifteen inclusive pair averages, and
  one-observation-per-tail Winsorization. None uses Huber influence weights.
- Fixed-month, contiguous momentum, regression, run, path, range, event, and
  XTI/XNG basket systems observe different information objects or exposures.

For the ten-return vector
`[.0188,-.0148,.0122,.0021,-.0084,-.0013,.0012,.0006,.0058,-.0160]`,
the locked Huber location is approximately `-0.0003122567` and therefore
sells, while the raw mean is `+0.00002` and the centered strict signed-rank
score is `+3`; both neighbors buy. The sample, scale, weights, updates, and
direction are therefore load bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_TEN_YEAR_SAME_CALENDAR_FIXED_SCALE_HUBER_LOCATION_SIGN_MONTHLY_RENEWAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`: complete-read,
  DOI-bearing peer-reviewed sources support same-calendar commodity
  information, explicit WTI own-return lineage, and bounded-influence
  location arithmetic. The exact conjunction remains untested.
- R2 `PASS`: host, clock, exact years, calendar endpoints, even median/MAD,
  constants, weights, update count, sign band, attempt, risk, stop, spread,
  and lifecycle are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history and MT5 state provide every
  runtime field; ten-year warm-up, energy labels, rolls, and CFD basis remain
  explicit falsification risks.
- R4 `PASS`: timestamps, logarithms, sorting, absolute deviations, fixed
  arithmetic, ATR risk plumbing, and execution state only; no trained signal,
  banned indicator, external feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Q02 retires on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any calendar, endpoint,
exact-year, median, MAD, scale, weight, iteration, sign, attempt, risk, stop,
lifecycle, or determinism defect. No failed result may be rescued by changing
the sample, estimator, tuning, iteration count, side, stop, hold, spread, or
retry contract.

Direct WTI adds crude-oil exposure absent from the stated certified
XAU/SP500/NDX/XNG book. That economic distinction does not prove low realized
correlation; unchanged Q09 alone owns portfolio overlap. This packet
authorizes one branch-only non-live card/build, strict Q01 validation, and one
paced Q02 enqueue if capacity permits. It excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
