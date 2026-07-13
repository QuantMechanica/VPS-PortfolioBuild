---
source_id: HOLLSTEIN-AGGVOL-2021
title: Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-12
created: 2026-07-12
created_by: Research
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - energy-volbeta
---

# Hollstein-Prokopczuk-Tharann Aggregate-Volatility Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-12 authorizes one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- Research reviewed the complete 57-page accepted article and online appendix,
  including the sample, characteristic definitions, aggregate-volatility
  results, alternative portfolio counts, subperiods, annual holding test, and
  limitations relevant to continuous aggregate-volatility sensitivity.
- This packet extracts only the smooth aggregate-volatility-beta
  characteristic. It does not authorize the paper's other anomaly variables.

## Primary Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017. DOI:
https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

## Relevant Source Locations

- Accepted-manuscript pp. 5-10: 26-commodity sample, explicit WTI and natural
  gas coverage, daily inputs, prior-twelve-month characteristic formation,
  monthly sorting, and one-month holding convention.
- pp. 10-12 and Table 4 Panel A: aggregate-volatility-beta results and the
  decomposition between continuous volatility and jump sensitivity.
- Appendix B pp. 26-27: aggregate volatility sensitivity is estimated from a
  daily twelve-month regression that also controls for the equity-market
  return.
- Online Appendix Table A1: cross-sectional regression evidence.
- Online Appendix Tables A3-A5: two-portfolio, subperiod, and annual-holding
  robustness checks. Monthly renewal is the source-aligned baseline.
- Conclusion p. 25: volatility-related characteristics are among the anomaly
  families considered in the broad commodity comparison.

## Source Rule

At each source month-end, estimate for each commodity from the previous twelve
months of daily observations:

```text
r_i,d = alpha_i + beta_market_i * market_d
                  + beta_smooth_vol_i * aggregate_smooth_vol_d + epsilon_i,d
```

Rank commodities by `beta_smooth_vol_i`, rebalance monthly, and form the
high-minus-low portfolio. The paper reports a positive 3.56% annualized
high-minus-low return for the continuous aggregate-volatility-beta sort under
its baseline portfolio construction. Ordinary inference is positive, but the
result does not clear the paper-wide multiple-testing threshold. That caveat
is binding and no source performance number enters a QM acceptance gate.

## Bounded Price-Native Translation

The source's smooth aggregate-volatility factor is option-derived and uses an
equity-market control. Darwinex CFD runtime has neither the matching option
surface nor the broad futures panel. Exact replication is unavailable and is
not claimed.

QM5_13151 builds a deterministic realized common-energy proxy from completed
XTIUSD.DWX and XNGUSD.DWX D1 returns:

```text
formation  = 272 synchronized completed D1 returns
rank_span  = latest 252 observations
w_i        = inverse_vol_i / sum(inverse_vol), fixed for the formation
energy_d   = w_XTI * r_XTI,d + w_XNG * r_XNG,d
rv20_d     = sample_std(energy_[d-19:d])
innovation = energy_d - mean(energy over rank_span)

smooth_d = rv20_d - rv20_[d-1]
           when abs(innovation) < 2.0 * sample_sd(energy), else 0

r_i,d = alpha_i + beta_energy_i * energy_d
                  + beta_smooth_i * smooth_d + epsilon_i,d
```

Require at least 200 non-jump observations, buy the higher `beta_smooth` leg,
short the lower leg, split fixed package risk equally, and hold to the next
broker month. The two-name factor, endogeneity, realized-volatility
substitution, return-based jump exclusion, continuous-CFD basis, and legging
are binding Q02 kill risks.

## Source Evidence Boundary

- The source sorts at least six of 26 collateralized commodity futures. QM
  ranks only two continuous energy CFDs, so the source diversification and
  cross-sectional inference do not transfer.
- The source factor is option-derived and market-wide. QM uses the change in
  realized volatility of an endogenous two-name energy benchmark. No source
  return, alpha, significance, drawdown, transaction-cost, or correlation
  value is inherited.
- The primary sample ends in 2015. QM's DWX evaluation window is out of sample.
- Zeroing realized-volatility changes on two-sigma return days is a coarse,
  price-only smooth/jump separation, not an options-based decomposition.
- Opposite-side equal fixed-risk legs reduce common energy direction but do
  not establish dollar, beta, volatility, factor, or realized neutrality.

## Non-Duplicate Boundary

- `QM5_13147_energy-jumpbeta` estimates exposure to two-sigma extreme-return
  days and buys low jump beta. QM5_13151 excludes those days from its
  volatility innovation and buys high smooth-volatility beta.
- `QM5_13146_energy-vov` ranks the dispersion of each contract's own rolling
  volatility level. QM5_13151 estimates regression sensitivity to changes in
  common energy realized volatility while controlling for market return.
- `QM5_13132_energy-bab` ranks total return beta and buys low beta. QM5_13151
  ranks the incremental smooth-volatility coefficient and buys high beta.
- `QM5_13133_energy-ivol` ranks residual return dispersion, not volatility-
  factor sensitivity.
- XTI/XNG ratio, spread, carry, trend, calendar, return-sign momentum, and
  incumbent `QM5_12567` RSI logic use different inputs and hypotheses.

Pre-allocation exact text and mechanic review found no aggregate smooth-
volatility-beta implementation. Verdict: `CLEAN_PRE_ALLOCATION`.

## R1-R4

- R1 source: PASS. Peer-reviewed primary paper with DOI and complete
  institutional accepted manuscript plus online appendix.
- R2 mechanical: PASS. Fixed synchronized return count, fixed inverse-vol
  benchmark, locked realized-volatility window and jump exclusion, fixed OLS
  controls, source-directed rank, monthly renewal, hard stops, and lifecycle
  guards.
- R3 data: PASS for the disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX
  D1 history is sufficient; exact option-factor replication is unavailable.
- R4 allowability: PASS. Native OHLC arithmetic, ATR safety stops, calendar,
  deal history, and broker metadata only; no ML, banned indicator, external
  runtime feed, grid, martingale, pyramiding, or adaptive PnL fit.

## Safety Boundary

No live setfile, T_Live path, AutoTrading action, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI change is authorized.
