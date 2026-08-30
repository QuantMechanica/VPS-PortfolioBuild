---
source_id: KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026
title: XNG same-calendar seasonality with a Bernoulli sign-score gate
publisher: QuantMechanica governed composite of peer-reviewed evidence and commit-pinned primary software
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_xng_same_calendar_sign_score_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
  - strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md
strategy_ids: [KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026_S01]
---

# XNG Same-Calendar Bernoulli Sign-Score Source Packet

## Bounded Source Basis

The durable source decision
`decisions/2026-08-30_xng_same_calendar_sign_score_source_approval.md` was
committed as `e74d496413d2a9ebaaab9979e85bc8e1806c0df3` before this
extraction. Both governed parent packets and the governed sign-score
arithmetic packet were read completely. Hash, byte, line, route, commit, and
blob evidence is bound in
`artifacts/qm5_xng_samecal_signscore_source_provenance_20260830.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, monthly renewal,
explicit natural-gas membership, and a minimum five-year history condition.

Papailias, Liu, and Thomakos (2021), "Return Signal Momentum," *Journal of
Banking & Finance* 124, 106063, DOI `10.1016/j.jbankfin.2021.106063`, supply
the deterministic nonnegative-return sign representation, equal weighting of
binary observations, explicit natural-gas membership, and a monthly decision
and holding clock.

The governed WTI sign-score packet carries complete provenance for the
commit-pinned R Core `prop.test.R` implementation at
`9deb2ebef8d0a2fe5cae965697ee4751af857bd1`, blob
`fc38bd4be1ba8630dbd224162ab5873ae6ac5261`. That primary software supplies
only the one-sample proportion-score arithmetic: default null probability
0.5, success and failure counts, expected counts under the null, and the
uncorrected Pearson score statistic. Runtime implements the reduced arithmetic
directly and does not invoke R.

No source tests this exact conjunction, an absolute XNG same-calendar sign
score, a strict one-standard-error trading gate, a Darwinex continuous CFD,
the locked execution plumbing, or the current portfolio. No source or sibling
return, alpha, significance, density, profit factor, cost, drawdown,
futures/CFD equivalence, correlation, or portfolio result transfers. The
score threshold is a locked QM falsification choice and not a conventional
statistical-significance claim; the EA never computes a p-value.

## Approved Mechanical Translation

On the first executable `XNGUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure, then persist current broker `yyyymm` before every
   fallible entry gate. A flat, blocked, rejected, failed, stopped, or
   restarted month never retries.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   completed XNG log returns for calendar month `M` in exact years
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. Missing older years are skipped without substitution;
   require at least five valid observations.
3. Map every finite return to one when nonnegative and zero when negative.
   Let `x` be the nonnegative count and `n` the valid observation count.
4. Against fixed null probability `p0=0.5`, with no continuity correction,
   compute the signed score
   `z=(x-n*p0)/sqrt(n*p0*(1-p0))=(2*x-n)/sqrt(n)`.
5. Above `+1.0+1e-10`, buy XNG. Below `-1.0-1e-10`, sell XNG. Equality, the
   inclusive interior band, or invalid state consumes the month flat. Signal
   magnitude never changes size.
6. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   fixed-risk budget. Attach a frozen `3.5*ATR(20,D1)` broker hard stop, no
   target, and reject crossed quotes, negative modeled spread, or spread above
   3,000 XNG points.
7. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. Runtime
uses only registered native MT5 D1 OHLC/timestamps, broker time, quotes,
contract metadata, positions, deals, terminal-persistent attempt state, and
V5 framework services. No curve, inventory, storage, weather, volume, open
interest, event feed, API, CSV, p-value table, trained output, banned signal
indicator, or optimizer result is read.

## Exact Statistical Contract

Let `r[0]..r[n-1]`, `5<=n<=10`, be finite exact-year XNG same-calendar log
returns and `x=sum(1[r[i]>=0])`:

```text
p0          = 0.5
denominator = sqrt(n * p0 * (1-p0)) = 0.5*sqrt(n)
score       = (x - n*p0) / denominator = (2*x-n)/sqrt(n)

score > +1.0 + 1e-10 => BUY XNG
score < -1.0 - 1e-10 => SELL XNG
otherwise              => FLAT
```

Require integer `0<=x<=n`, finite positive denominator, and finite score. No
continuity correction, exact-binomial p-value, chi-squared lookup, return
magnitude, arithmetic mean, sample variance, median, rank weight, robust
location, current-month input, contrarian sign, magnitude sizing, or fallback
estimator is equivalent.

R Core's uncorrected one-sample Pearson statistic at `p0=0.5` is
`X2=(x-n/2)^2/(n/2)+((n-x)-n/2)^2/(n/2)=(2*x-n)^2/n`. The locked signed score
is `sign(x/n-p0)*sqrt(X2)`, which reduces to the expression above.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,713 registry identities, 1,359 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced three
expected fuzzy neighbors. Receipt:
`artifacts/qm5_xng_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`F6E5C50549A7A43C7BD047CAA44303A699F2DDF139ACD599EBD5090CFFD80AF4`.

- `QM5_20100_xng-samecal` follows the arithmetic mean of return magnitudes
  and normally chooses a side. This packet discards magnitude and stays flat
  inside a sample-size-aware binary-sign band. For
  `[0.09,-0.01,-0.01,-0.01,-0.01]`, the raw mean buys while this score sells.
- `QM5_41205_xng-samecal-huber10` preserves metric distances through an even
  median, MAD scale, and fixed-step Huber location. This packet reduces the
  sample to an unweighted Bernoulli count standardized by null variance.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon cumulative-RSI(2)
  pullback under long-trend context. This packet has no RSI, oscillator,
  contiguous pullback, or intramonth renewal.
- `QM5_41212_wti-samecal-signscore` uses the same transparent statistic but
  observes and owns WTI. It cannot read or trade XNG. This packet is the
  explicitly permitted new XNG carrier/mechanic combination, not a claim to a
  globally new statistical family.
- `QM5_41213_xauxag-samecal-signscore` applies the score to synchronized
  relative gold-minus-silver returns and owns two opposite metal legs. It
  cannot express a single-gas directional state.

The exact XNG information object, null-variance abstention rule, durable
monthly attempt state, and single-gas position jointly change direction,
participation, and exposure relative to the incumbent XNG logic.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XNG_SAMECAL_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATISTIC_SINGLE_CARRIER_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`:
  complete-read, peer-reviewed same-calendar commodity evidence explicitly
  includes natural gas; peer-reviewed return-sign evidence explicitly
  includes natural gas; commit-pinned primary software fixes the score
  arithmetic. The exact conjunction and threshold are untested.
- R2 `PASS`: clock, normalized endpoints, exact-year bound, sample floor,
  binary map, null, denominator, strict score band, side, attempt, fixed risk,
  stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XNGUSD.DWX` D1 history and MT5 state provide every
  runtime field; label, history, roll, financing, gaps, and CFD-basis risks
  remain explicit.
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

The monthly XNG information clock is structurally distinct from the stated
book's daily cumulative-RSI pullback but does not prove factor or portfolio
independence. Only unchanged Q09 may judge realized overlap. This packet
authorizes one branch-only non-live card/build, strict Q01 validation, and one
paced Q02 enqueue if capacity permits. It excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
