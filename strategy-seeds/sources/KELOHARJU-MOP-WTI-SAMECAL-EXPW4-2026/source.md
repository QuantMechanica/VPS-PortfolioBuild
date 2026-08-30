---
source_id: KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026
title: WTI same-calendar seasonality with fixed four-year exponential recency weights
publisher: QuantMechanica governed composite of peer-reviewed evidence
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_wti_same_calendar_exponential_weight_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
  - strategy-seeds/sources/MOP-TSMOM-2012/source.md
  - strategy-seeds/sources/MOP-WTI-EXPW-2026/source.md
strategy_ids: [KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026_S01]
---

# WTI Same-Calendar Exponential-Weight Source Packet

## Bounded Source Basis

The durable source decision
`decisions/2026-08-30_wti_same_calendar_exponential_weight_source_approval.md`
was committed as `ed236e3e0d` before this extraction. All three governed
packets named by that approval were then read completely. Hash, byte, line,
and repository-commit evidence is bound in
`artifacts/qm5_wti_samecal_expw4_source_provenance_20260830.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, explicit crude-oil
membership, monthly renewal, and a minimum five-year history condition. Their
commodity test ranks a diversified futures cross-section. It does not report
this single-WTI absolute-sign translation.

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supply explicit WTI membership, own-return
directional interpretation, and monthly renewal. They do not use a
same-calendar sample or exponential weights for this rule.

The governed `MOP-WTI-EXPW-2026` packet fixes auditable base-two exponential
weight arithmetic and the orientation that most recent information has age
zero. Its parent paper does not prescribe exponential weights or any
half-life. This packet translates the age unit from consecutive months to
exact prior calendar years and fixes the half-life at four calendar years
before Q02.

No source tests this exact conjunction, the four-year half-life, an absolute
WTI same-calendar weighted sign, a Darwinex continuous CFD, the locked
execution plumbing, or the current portfolio. No source or sibling return,
alpha, significance, density, profit factor, cost, drawdown, futures/CFD
equivalence, correlation, or portfolio result transfers. The decay kernel is
a locked QM falsification choice, not a fitted or source-claimed optimum.

## Approved Mechanical Translation

On the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure, then persist current broker `yyyymm` before every
   fallible entry gate. A flat, blocked, rejected, failed, stopped, or
   restarted month never retries.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   completed WTI log returns for calendar month `M` in exact years
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. Missing years are skipped without substitution; require at
   least five valid observations. The current decision month contributes no
   endpoint.
3. For exact year lag `k` in `1..10`, assign calendar age `a=k-1` and fixed
   weight `w=2^(-a/4.0)`. Missing years contribute neither return nor weight
   and never compress the age of an older observation.
4. Compute the normalized weighted mean. Above `+1e-12`, buy WTI. Below
   `-1e-12`, sell WTI. Equality or invalid state consumes the month flat.
   Signal magnitude never changes risk.
5. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   fixed-risk budget. Attach a frozen `3.5*ATR(20,D1)` broker hard stop, no
   target, and reject crossed quotes, negative modeled spread, or spread above
   1,500 WTI points.
6. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. Runtime
uses only registered native MT5 D1 OHLC/timestamps, broker time, quotes,
contract metadata, positions, deals, terminal-persistent attempt state, and
V5 framework services. No curve, inventory, storage, weather, volume, open
interest, event feed, API, CSV, trained output, banned signal indicator, or
optimizer result is read.

## Exact Statistical Contract

Let `r_k`, for valid exact lags `k` in `1..10`, be the finite WTI log return
for the upcoming calendar month in year `Y-k`. Let `V` be the set of valid
lags and require `|V|>=5`:

```text
age_k       = k - 1
half_life   = 4.0 calendar years
weight_k    = 2 ^ (-age_k / half_life)
weight_sum  = sum(weight_k, k in V)
weighted_sum= sum(weight_k * r_k, k in V)
weighted_mean = weighted_sum / weight_sum

weighted_mean > +1e-12 => BUY WTI
weighted_mean < -1e-12 => SELL WTI
otherwise               => FLAT
```

Every included weight must be finite and positive. `weight_sum` must be
finite and positive, and the weighted sum and mean must be finite. The newest
available exact year does not automatically receive age zero: only `Y-1` has
age zero. Thus if `Y-1` is missing and `Y-2` is valid, its weight remains
`2^(-1/4)`.

There is no arithmetic equal-weight fallback, sample sort, tail cap, median,
MAD, Huber iteration, sign count, sample variance, t statistic, confidence
band, fitted decay, alternate base, adaptive half-life, current-month input,
contrarian flip, magnitude sizing, or fallback estimator.

## Non-Duplicate Boundary

The fail-closed corrected-root checker scanned 4,722 registry identities,
1,360 card files, and 45 Strategy Wiki nodes. It found no exact identity and
surfaced one expected fuzzy neighbor. Receipt:
`artifacts/qm5_wti_samecal_expw4_preallocation_dedup_20260830.json`, SHA-256
`60C966AE7522F051B4FE658923935C253C160CE2D054070D245CC5554FDD760F`.

- `QM5_20099_wti-samecal` assigns equal weight to every available exact
  prior-year return. This packet's year-age kernel can reverse that signal.
  For recent-to-old returns
  `[-0.04,-0.04,-0.04,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03]`,
  the equal mean is `+0.009` and buys, while the four-year-half-life weighted
  sum is negative and this packet sells.
- `QM5_20279_wti-expw-mom` weights twelve contiguous recent monthly returns
  with a three-month half-life. This packet samples one matching calendar
  month from each prior year, uses calendar-year ages and a four-year
  half-life, and ignores every intervening month.
- `QM5_41204_wti-samecal-huber10` uses an even median, raw MAD, fixed scale,
  and 32 Huber updates. This packet never sorts, clips, estimates scale, or
  iterates; exact calendar age alone changes influence.
- `QM5_41211_wti-samecal-tstat` uses an equal-weight mean divided by sample
  standard error and may abstain inside a confidence band. This packet has no
  variance state or confidence gate and normally chooses a side.
- `QM5_41212_wti-samecal-signscore` discards return magnitudes into equal
  Bernoulli signs. This packet retains metric return magnitude and applies
  deterministic year-age decay.

The exact same-calendar sample, uncompressed year ages, four-year base-two
kernel, normalized weighted sign, durable monthly attempt state, and
single-WTI position jointly change direction, information influence, and
exposure relative to the built neighbors.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_EXPONENTIAL_YEAR_DECAY_DIRECTION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_DECAY_AND_SINGLE_CARRIER_CFD_TRANSLATION_RISK`:
  complete-read, peer-reviewed same-calendar commodity evidence explicitly
  includes crude oil; peer-reviewed time-series evidence explicitly includes
  WTI; the governed arithmetic packet fixes base-two decay. The exact
  conjunction and half-life are untested.
- R2 `PASS`: clock, normalized endpoints, exact-year bound and ages,
  missing-year rule, sample floor, base, exponent, half-life, normalization,
  side, attempt, fixed risk, stop, spread, and lifecycle are deterministic and
  locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history and MT5 state provide every
  runtime field; label, history, roll, financing, gaps, and CFD-basis risks
  remain explicit.
- R4 `PASS`: timestamps, logarithms, fixed powers, multiplication, addition,
  division, comparisons, ATR-risk plumbing, and execution state only; no
  trained signal, banned indicator, external feed, grid, martingale, scale-in,
  or pyramid.

## Falsification And Safety Boundary

Q02 retires on zero positions, fewer than five completed positions in any
full post-warm-up year, nonpositive governed economics, or any calendar,
endpoint, exact age, weight, normalization, side, attempt, risk, stop, spread,
lifecycle, or determinism defect. No failed result may be rescued by changing
the sample, half-life, age compression, tie rule, direction, carrier, stop,
hold, spread, retry contract, or adding a fallback.

Direct WTI is an economically different carrier from the certified
XAU/SP500/NDX/XNG book but does not prove factor or portfolio independence.
Only unchanged Q09 may judge realized overlap. This packet authorizes one
branch-only non-live card/build, strict Q01 validation, and one paced Q02
enqueue if capacity permits. It excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
