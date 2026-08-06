---
source_id: HOLLSTEIN-VOV-2021
title: Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directives 2026-07-11 and 2026-08-06
created: 2026-07-11
created_by: Research
last_updated: 2026-08-06
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - energy-vov
  - xauxag-vov-rank
---

# Hollstein-Prokopczuk-Tharann Volatility-of-Volatility Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 authorizes one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete 57-page accepted article and online appendix were read end to
  end: theory and motivation, data, futures/options construction, anomaly
  definitions, portfolio tests, factor regressions, alternative portfolio
  counts, subperiods, annual holds, tables, and bibliography.
- This packet extracts one rule only: the paper's monthly cross-sectional
  volatility-of-volatility sort, translated to an XTI/XNG price-native proxy.
- The OWNER mission dated 2026-08-06 authorizes the same locked price-native
  estimator and low-minus-high direction as one paired `XAUUSD.DWX` /
  `XAGUSD.DWX` carrier extension. It does not authorize an estimator sweep,
  implied-volatility claim, direction change, or post-result rescue.

## Primary Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017. DOI:
https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

## Relevant Source Locations

- Accepted-manuscript pp. 5-9: 26-commodity sample, WTI and natural gas,
  fixed-maturity futures returns, option cleaning, monthly sort design, and
  one-year formation convention.
- p. 16 and Table 4 Panel D: high-minus-low VoV has a negative mean return and
  negative alphas, so the mechanical direction is low VoV long/high VoV short.
- Appendix B p. 29: VoV equals the population standard deviation of 252 daily
  implied-volatility observations divided by their mean.
- Online Appendix Table A1: the univariate cross-sectional VoV slope is
  negative and statistically significant.
- Online Appendix Table A3 Panel D: the two-portfolio high-minus-low VoV result
  remains negative; this is the source result most relevant to a two-leg port.
- Online Appendix Table A4 Panel D: the direction persists but weakens in the
  later source subperiod.
- Online Appendix Table A5 Panel D: annual holds weaken the effect, supporting
  the source's monthly renewal rather than a twelve-month hold.

## Source Rule

At each month-end, the source calculates each commodity's VoV from 252 daily
option-implied volatility observations:

```text
mean_iv = average(iv[d], d=1..252)
vov     = sqrt(sum((iv[d] - mean_iv)^2) / 252) / mean_iv
```

It ranks the commodity cross-section, holds the sorted portfolios for one
month, and reports the high-minus-low return. Because that spread is negative,
the implementable direction is buy low VoV and short high VoV.

## Bounded Price-Native Translation

Darwinex CFD runtime has no commodity option chain or model-free implied
variance. The EA therefore does not claim replication. For each energy leg it
constructs 252 overlapping daily realized-volatility estimates, each from 20
completed D1 log returns, then applies the source's exact dispersion-over-mean
VoV transform to those estimates:

```text
rv[d]       = sample_std(last 20 D1 log returns) * sqrt(252)
mean_rv     = average(rv[d], d=1..252)
realized_vov = sqrt(sum((rv[d] - mean_rv)^2) / 252) / mean_rv
```

On the first tradable D1 host bar of each broker month, buy the lower realized-
VoV XTI/XNG leg and short the higher leg. Split fixed package risk equally,
attach independent frozen ATR hard stops, and close at the next month or stale
limit. The implied-to-realized substitution is a binding Q02 kill risk, not an
equivalence claim.

The 2026-08-06 carrier extension,
`HOLLSTEIN-VOV-2021_XAU_XAG_S02`, preserves that estimator and lifecycle on
the registered precious-metal carrier:

- host the logical basket on `XAUUSD.DWX` D1 and use 273 completed closes for
  both XAU and XAG;
- construct exactly 252 overlapping realized-volatility observations, each
  from exactly 20 completed D1 log returns and sample variance denominator 19;
- divide the population standard deviation of those 252 observations by
  their arithmetic mean;
- buy the lower-realized-VoV metal and short the higher-realized-VoV metal;
- split one `RISK_FIXED=1000` package into equal stop-risk halves, attach
  frozen per-leg ATR hard stops, renew at the next broker-month transition,
  persist the consumed attempt, and repair any orphan; and
- consume a numerical tie or invalid-data month without a trade or retry.

This is a two-CFD carrier falsification, not a source result for gold versus
silver. Opposite directions and equal fixed-risk halves do not establish
dollar, beta, volatility, factor, or portfolio neutrality. The unchanged Q09
gate alone may establish realized correlation to the certified book.

## Source Evidence Boundary

- The source studies 26 futures and requires a broad sort; QM ranks only two
  continuous CFDs.
- The source signal is option-implied VoV. The price-native realized-VoV
  carrier may contain different information and receives no inherited return.
- The source sample ends in 2015. QM's 2017+ window is out-of-sample relative
  to the paper.
- The modern subperiod result is weaker, and controls for momentum plus roll
  yield attenuate the cross-sectional slope.
- Futures roll/collateral returns, options, broad diversification, transaction
  costs, and portfolio correlation do not transfer to this CFD package.

## Non-Duplicate Boundary

- `QM5_13046`, `QM5_13051`, and `QM5_13091` use high realized-volatility
  regimes to gate directional stretch fades; they do not trade VoV rank.
- `QM5_13133_energy-ivol` ranks OLS residual-volatility level against a
  commodity factor; it does not measure the instability of rolling volatility.
- `QM5_13139_energy-cv-rank` divides 36-month return variance by mean return;
  it does not calculate dispersion across daily rolling-volatility estimates.
- `QM5_13129`, `QM5_13130`, `QM5_13131`, `QM5_13141`, and `QM5_13143` rank
  signed semivariance, maximum returns, kurtosis, idiosyncratic asymmetry, or
  expected shortfall rather than volatility-of-volatility.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only RSI pullback.

The canonical pre-allocation checker found no exact duplicate across 4,032
registry rows and 334 cards. Its fuzzy matches were the expected shared-source
and generic `energy-*` names. Manual input/formula/direction/window review:
`CLEAN_AFTER_MANUAL_REVIEW`.

For `S02`, the deterministic checker scanned 4,293 EA-registry rows and 409
canonical cards. It found no exact identity and five lexical fuzzy matches.
Manual review fixes the boundary:

- `QM5_13146_energy-vov` preserves the identical locked estimator and
  direction on XTI/XNG. It reached Q07 and then failed Q08; that adverse
  sibling result is disclosed and no efficacy transfers to this carrier.
- `QM5_20233_xauxag-skew-rank` uses a centered third moment,
  `QM5_20234_xauxag-rsj` uses signed semivariance, and
  `QM5_20235_xauxag-es-rank` averages the worst five percent of returns. None
  measures dispersion across a path of rolling realized-volatility estimates.
- Existing XAU/XAG price-ratio, OLS-residual, quantile-envelope, momentum,
  calendar, shock, and idiosyncratic-volatility builds use different
  information objects, transforms, or clocks.
- `QM5_1212_carver-kurtsabs`, `QM5_1221_carver-kurtsrv`, and
  `QM5_10322_realized-moments` use daily/weekly higher-moment composites, not
  this pure monthly nested realized-VoV rank.
- `QM5_12567_cum-rsi2-commodity` is short-horizon, long-only RSI pullback
  logic rather than an opposite-side monthly uncertainty rank.

The 20-return inner window, 252 overlapping RV observations, sample variance
inside RV, population dispersion across RV, division by mean RV,
low-minus-high direction, XAU/XAG carrier, monthly renewal, equal risk halves,
and no same-month retry are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## R1-R4

- R1 source: PASS. One peer-reviewed primary paper with DOI and complete
  institutional accepted manuscript; one source ID is retained for lineage.
- R2 mechanical: PASS. Fixed nested return/RV/VoV estimators, monthly rank,
  low-minus-high direction, equal fixed risk, hard stops, stale close,
  restart-safe attempt guard, and orphan cleanup are deterministic.
- R3 data: PASS for the disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX
  D1 history is sufficient for `S01`; registered XAUUSD.DWX and XAGUSD.DWX D1
  history is sufficient for `S02`. Absent options make exact replication
  impossible and remain a Q02 falsification risk.
- R4 allowability: PASS. Native OHLC arithmetic, ATR safety stops, calendar,
  and broker metadata only; no ML, banned indicator, grid, martingale,
  pyramiding, external runtime feed, or adaptive PnL fit.

## Safety Boundary

No live setfile, T_Live path, AutoTrading action, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI change is authorized.

The 2026-08-06 mission additionally authorizes one durable G0 record, card,
branch-only non-live build, strict compile, and paced Q02 enqueue for `S02`.
It excludes a manual backtest; live, demo, or shadow setfiles; T_Live;
AutoTrading; deploy or T_Live manifests; portfolio admission; portfolio-gate
changes; and correlation waivers.
