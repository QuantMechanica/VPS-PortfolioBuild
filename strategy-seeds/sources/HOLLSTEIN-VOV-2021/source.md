---
source_id: HOLLSTEIN-VOV-2021
title: Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - energy-vov
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

## R1-R4

- R1 source: PASS. One peer-reviewed primary paper with DOI and complete
  institutional accepted manuscript; one source ID is retained for lineage.
- R2 mechanical: PASS. Fixed nested return/RV/VoV estimators, monthly rank,
  low-minus-high direction, equal fixed risk, hard stops, stale close,
  restart-safe attempt guard, and orphan cleanup are deterministic.
- R3 data: PASS for the disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX
  D1 history is sufficient; absent options make exact replication impossible
  and remain a Q02 falsification risk.
- R4 allowability: PASS. Native OHLC arithmetic, ATR safety stops, calendar,
  and broker metadata only; no ML, banned indicator, grid, martingale,
  pyramiding, external runtime feed, or adaptive PnL fit.

## Safety Boundary

No live setfile, T_Live path, AutoTrading action, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI change is authorized.
