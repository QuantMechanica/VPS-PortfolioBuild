---
source_id: HOLLSTEIN-XNG-KURT-2026
title: XNG historical-kurtosis premium extraction from Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: bounded_peer_reviewed_paper_extraction
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20297_xng_kurt_prem_g0.md
created: 2026-08-13
created_by: Research+Development
parent_source: strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md
parent_sha256: 66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - xng-kurt-prem
---

# XNG Historical-Kurtosis Premium Source Packet

## Approval And Complete-Read Boundary

The durable OWNER mission and G0 decision dated 2026-08-13 authorize one new
structural, low-frequency commodity/energy card, non-live V5 build, and paced
Q02 enqueue. The governed parent packet records an end-to-end read of the
57-page accepted article and online appendix, including definitions,
portfolio sorts, factor tests, alternate portfolio counts, subperiods, annual
holds, tables, and explicit natural-gas membership. The parent packet and this
bounded extraction were read completely before card drafting.

Primary citation: Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern
(2021), "Anomalies in Commodity Futures Markets," *Quarterly Journal of
Finance* 11(4), article 2150017, DOI
`10.1142/S2010139221500178`.

The institutional accepted manuscript is hosted at
`https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf`. The complete-read
parent is content-bound by SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.
Durable extraction approval is
`decisions/2026-08-13_qm5_20297_xng_kurt_prem_g0.md`.

## Relevant Source Claims

- Pages 9-10 define month-end cross-sectional ranking, a one-month holding
  interval, fully collateralized long-short construction, and a minimum
  six-commodity universe.
- Appendix B page 27 defines historical kurtosis from prior-twelve-month daily
  returns as the fourth central moment divided by squared sample variance. It
  is Pearson kurtosis, not excess kurtosis.
- Page 19 and Table 4 Panel F report a positive full-sample relation between
  historical kurtosis and subsequent commodity returns.
- Table A1 reports an insignificant Fama-MacBeth slope. Table A3 Panel F shows
  a positive but insignificant two-portfolio high-minus-low result.
- Table A4 Panel F reverses the premium's sign, insignificantly, in the
  December 2000-December 2015 post-financialization subperiod.
- Table 1 explicitly includes natural gas in the source universe.

The article therefore supplies the statistic, high-minus-low orientation,
monthly decision clock, and natural-gas membership. It does not supply a
profitable single-XNG time-series threshold rule.

## Bounded QM Mechanization

On the first processed `XNGUSD.DWX` D1 bar after a genuine broker-month
transition, load exactly 253 completed positive finite D1 closes and form 252
chronological simple returns:

```text
r[d] = close[d] / close[d-1] - 1
mu = sum(r[d]) / 252
s2 = sum((r[d] - mu)^2) / 251
m4 = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

Use the fixed Pearson-normal benchmark `3.0` as the absolute time-series
pivot: buy natural gas above `3.0 + 1e-12`, sell natural gas below
`3.0 - 1e-12`, and consume the month flat inside the tolerance or on invalid
state. Hold until the next broker-month transition, subject to a forty-
calendar-day stale guard, a frozen `3.5 * ATR(20,D1)` hard stop, and a
`2500`-point entry-spread ceiling.

The absolute benchmark-three map is a transparent QM hypothesis. The source
ranks at least six collateralized futures and does not claim that Pearson
kurtosis above three predicts positive natural-gas returns or that a value
below three predicts negative natural-gas returns. The sample estimator is
also not exactly unbiased around three in finite samples. No source alpha,
return, Sharpe, drawdown, XNG-only effect, CFD equivalence, cost, density,
correlation, or portfolio result is imported. Q02 is a low-prior
falsification.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,362 registry rows and 473 root
cards. It found no exact slug or strategy identity and returned eight expected
fuzzy source-family neighbors for manual review.

- `QM5_13131_energy-kurt-rank` computes the same source estimator separately
  for XTI and XNG, buys the higher value, shorts the lower value, and manages a
  two-leg package. This candidate reads only XNG and maps it around three.
- `QM5_20291_xauxag-kurt-rk` is the corresponding two-metal relative rank. It
  has two histories, two magics, shared basket risk, and orphan repair.
- `QM5_20295_wti-kurt-prem` preserves the estimator and direction on WTI. The
  new XNG carrier has distinct history, contract economics, spread guard,
  magic, and Q02 lineage and inherits no WTI evidence.
- `QM5_20296_xng-skew-prem` maps a centered third standardized moment around
  zero and follows the low-skew premium. This candidate uses a fourth central
  moment, source sample-variance denominator, benchmark three, and high-
  kurtosis direction.
- `QM5_13130_xti-xng-lowmax` and `QM5_20294_xauxag-max-rk` average only the five
  largest daily returns and buy the lower value; they do not measure the full
  return distribution's fourth moment.
- Legacy kurtosis EAs combine skew, daily scaling, or intraday composites and
  do not implement a pure monthly outright-XNG Pearson-kurtosis state.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback, not a symmetric monthly fourth-moment premium.

The exact 252 simple returns, source denominators, Pearson fourth moment,
fixed benchmark three, high-kurtosis long/low-kurtosis short map, outright XNG
carrier, and monthly consumed-attempt lifecycle are jointly load-bearing.
Verdict: `CLEAN_AUTHORIZED_XNG_CARRIER_AFTER_MANUAL_REVIEW`.

## R1-R4 Boundary

- R1: PASS with adverse evidence preserved. The source is a named peer-
  reviewed article with DOI, institutional full text, complete-read evidence,
  and explicit natural-gas membership.
- R2: PASS as a falsifiable QM translation. Observation count, chronology,
  estimator denominators, pivot, tolerance, direction, attempt, stop, monthly
  rollover, and stale exit are fixed.
- R3: PASS with futures-to-CFD risk. Registered `XNGUSD.DWX` D1 OHLC and native
  V5 execution state supply every runtime input.
- R4: PASS. The rule is deterministic arithmetic without a trained output,
  prohibited signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Kill Boundary

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on an incorrect observation count or orientation, wrong variance/fourth-
moment denominator, excess rather than Pearson kurtosis, fitted pivot,
reversed direction, repeated monthly attempt, missing hard stop, risk
mismatch, stale hold, or nondeterminism. No post-result threshold, formula,
direction, stop, hold, spread, retry, or carrier rescue is authorized.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
