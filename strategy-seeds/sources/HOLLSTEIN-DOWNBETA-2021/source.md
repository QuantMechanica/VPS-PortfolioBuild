---
source_id: HOLLSTEIN-DOWNBETA-2021
title: Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-12
created: 2026-07-12
created_by: Research
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - energy-downbeta
---

# Hollstein-Prokopczuk-Tharann Downside-Beta Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-12 authorizes one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- Research reviewed the complete 57-page accepted article and online appendix
  end to end, including data construction, all characteristic definitions,
  portfolio sorts, factor regressions, alternative portfolio counts,
  subperiods, annual holding tests, tables, and bibliography.
- This packet extracts only the paper's downside-beta characteristic. It does
  not authorize another characteristic or import evidence from the existing
  Hollstein MAX, VoV, aggregate-jump, aggregate-volatility, or 36-month
  packets.

## Primary Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017. DOI:
https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

## Relevant Source Locations

- Accepted-manuscript pp. 5-10: 26-commodity sample, explicit WTI and natural
  gas coverage, fixed-maturity commodity excess returns, prior-twelve-month
  characteristic formation, month-end sorts, monthly renewal, and
  collateralized long-short construction.
- p. 12 and Table 4 Panel B: the three-portfolio downside-beta high-minus-low
  return is -1.37% annualized and insignificant; all reported factor-model
  alphas are also insignificant.
- Appendix B p. 27: DownBeta is the slope from a daily regression of commodity
  excess return on market excess return, estimated only when market excess
  return is below its prior-twelve-month daily average.
- Online Appendix Table A1: the univariate Fama-MacBeth downside-beta slope is
  0.0005 with a 0.0534 standard error and is insignificant.
- Online Appendix Table A3 Panel B: high-minus-low mean returns for two,
  three, four, and five portfolios are -0.84%, -1.37%, -0.44%, and -1.65%
  annualized, respectively; none is significant.
- Online Appendix Table A4 Panel B: the high-minus-low sign is unstable across
  source subperiods (-3.83%, +1.90%, and -0.40% annualized).
- Online Appendix Table A5 Panel B: the annual-holding high-minus-low return is
  -0.60% and insignificant, while the source's general evidence favors
  regular monthly renewal over annual holds.
- Conclusion p. 25: downside beta is among the characteristics that mostly
  produce near-zero, insignificant commodity returns.

## Source Rule

At each source month-end, estimate for each commodity using the previous
twelve months of daily observations:

```text
down_day_d = (market_excess_d < average(market_excess over prior 12 months))

r_i,d = alpha_i + beta_down_i * market_excess_d + epsilon_i,d
         estimated only for observations where down_day_d is true
```

Rank commodities by `beta_down_i`, rebalance monthly, and form a
high-minus-low portfolio. The source high-minus-low return is negative, so the
mechanical sign translated to QM is low downside beta long and high downside
beta short.

This sign is not a demonstrated premium. The authors explicitly conclude that
"downside beta risk appears to be not priced in the cross-section of commodity
returns" (accepted manuscript p. 12). The portfolio-count evidence is
consistently negative but insignificant, the cross-sectional slope is null,
and the source subperiods are unstable. Q02 is therefore a strict
out-of-sample falsification with a null prior.

## Bounded Price-Native Translation

The source uses commodity-futures excess returns and CRSP market excess
returns. Native Darwinex backtests do not contain the source's risk-free-rate
series or CRSP total-return series. QM5_13203 uses only synchronized completed
D1 closes and discloses two proxies:

```text
formation = 252 synchronized completed D1 simple returns
market_d  = simple return of read-only SP500.DWX
market_mu = average(market_d over all 252 observations)
down_day  = market_d < market_mu

r_i,d = alpha_i + beta_down_i * market_d + epsilon_i,d
         estimated only on down_day observations
```

Require at least 100 qualifying down-market observations and positive market
variance. Buy the lower-beta XTI/XNG leg, short the higher-beta leg, split
fixed package risk equally, and hold to the next broker month. SP500.DWX is a
read-only factor and is never ordered, sized, assigned a traded magic, or
included in package PnL.

Using raw CFD returns implicitly sets the unavailable daily risk-free return
to zero. SP500.DWX is an OWNER-provided custom backtest symbol rather than the
source CRSP total-market index. Those substitutions, the two-name rank,
continuous-CFD basis, sample truncation to the SP500 overlap, gaps, and
legging are binding Q02 kill risks.

## Source Evidence Boundary

- The source rejects a reliable downside-beta premium. The low-minus-high
  direction merely reverses the source's insignificant negative
  high-minus-low sign; it is not a source-supported performance forecast.
- The source ranks at least six of 26 collateralized commodity futures. QM
  ranks two continuous energy CFDs, so breadth and diversification do not
  transfer.
- The source market factor is CRSP market excess return and the dependent
  variable is commodity excess return. Raw SP500.DWX and energy-CFD returns
  are disclosed price-only proxies with no risk-free series.
- SP500.DWX starts later than the energy histories and is backtest-only. The
  common synchronized endpoint determines the available Q02 sample.
- Opposite-side equal fixed-risk legs reduce common energy direction but do
  not establish dollar, beta, volatility, equity-factor, or realized market
  neutrality.
- No source return, alpha, significance, drawdown, transaction-cost, or
  correlation statistic is inherited by the card.

## Non-Duplicate Boundary

- `QM5_13132_energy-bab` estimates unconditional lag-augmented Dimson beta to
  an endogenous energy benchmark, shrinks beta toward one, and inverse-beta
  sizes. DownBeta uses contemporaneous SP500.DWX returns only on below-average
  market days, no shrinkage, and equal fixed-risk halves.
- `QM5_13147_energy-jumpbeta` estimates incremental sensitivity to an
  endogenous realized common-energy jump factor while controlling for common
  energy return. DownBeta uses an external read-only equity-index proxy and a
  conditional observation subset, not a jump regressor.
- `QM5_13151_energy-volbeta` estimates a second-factor coefficient on changes
  in smooth common-energy realized volatility. DownBeta estimates one
  conditional equity-market slope and contains no volatility estimator.
- `QM5_13133_energy-ivol` ranks residual-return dispersion rather than a
  conditional systematic beta.
- XTI/XNG ratio, return-spread, carry, trend, calendar, return-sign momentum,
  and incumbent `QM5_12567` RSI logic use different inputs and hypotheses.

Targeted exact-text, slug, strategy-ID, and manual mechanic review found no
DownBeta or downside-beta commodity EA/card. Verdict:
`CLEAN_PRE_ALLOCATION`.

## R1-R4

- R1 source: PASS with a binding null-evidence caveat. The single primary
  source is a peer-reviewed article with DOI and complete institutional
  accepted manuscript plus online appendix.
- R2 mechanical: PASS. Fixed synchronized return count, fixed down-market
  definition, intercept OLS, minimum-observation and variance guards, locked
  low-minus-high direction, monthly renewal, hard stops, and lifecycle guards
  are deterministic.
- R3 data: PASS for the disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX
  provide traded D1 history; registered SP500.DWX provides a read-only
  backtest factor. Risk-free and CRSP fidelity are unavailable and remain
  falsification risks.
- R4 allowability: PASS. Native OHLC arithmetic, ATR safety stops, calendar,
  deal history, position state, and broker metadata only; no ML, banned
  indicator, external runtime feed, grid, martingale, pyramiding, or adaptive
  PnL fit.

## Safety Boundary

SP500.DWX is read-only and backtest-only. No order may be sent on it. No live
setfile, T_Live path, AutoTrading action, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI change is authorized.
