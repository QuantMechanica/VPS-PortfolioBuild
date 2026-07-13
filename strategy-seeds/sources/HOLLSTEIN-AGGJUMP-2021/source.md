---
source_id: HOLLSTEIN-AGGJUMP-2021
title: Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - energy-jumpbeta
---

# Hollstein-Prokopczuk-Tharann Aggregate-Jump Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 authorizes one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The same complete 57-page accepted article and online appendix were already
  reviewed end to end for the approved HOLLSTEIN-VOV-2021 source packet. This
  extraction rechecked the data, characteristic construction, aggregate-jump
  result, portfolio tables, robustness discussion, appendices, and source
  limitations relevant to jump sensitivity.
- This packet extracts only the aggregate-jump-risk characteristic. It does
  not authorize the paper's other anomaly variables.

## Primary Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017. DOI:
https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

## Supplementary Commodity-Jump Context

Nguyen, Duy B. B., and Marcel Prokopczuk (2019), "Jumps in Commodity
Markets," *Journal of Commodity Markets* 13, 55-70. DOI:
https://doi.org/10.1016/j.jcomm.2018.10.002.

The supplement documents that price jumps are rare but material in commodity
markets and that within-sector jump correlations can be high for energy. It
supports testing a common-energy realized-jump carrier, but it does not supply
the expected-return direction. Direction comes only from the primary paper.

## Relevant Source Locations

- Accepted-manuscript pp. 5-10: 26-commodity sample, explicit WTI and natural
  gas coverage, daily inputs, twelve-month characteristic formation, monthly
  sorting, and one-month holding convention.
- pp. 10-12 and Table 4 Panel A: the high-minus-low aggregate-jump-sensitivity
  portfolio has a negative mean return and negative factor-model alphas; the
  source interprets high positive jump sensitivity as crisis-hedging demand.
- Appendix B pp. 26-27: aggregate jump sensitivity is the jump-factor
  coefficient in a daily twelve-month regression that also controls for the
  equity-market return.
- Online Appendix Table A1: the univariate cross-sectional aggregate-jump
  slope is negative.
- Online Appendix Tables A3-A5: alternative portfolio counts, subperiods, and
  annual holds bound the robustness; annual renewal is weaker than monthly.
- Conclusion p. 25: jump risk is one of the paper's significant and robust
  commodity premia.

## Source Rule

At each source month-end, estimate for every commodity using the prior twelve
months of daily data:

```text
r_i,d = alpha_i + beta_market_i * market_d
                  + beta_jump_i * aggregate_jump_d + epsilon_i,d
```

Rank commodities by `beta_jump_i`, rebalance monthly, and form the
high-minus-low portfolio. The reported spread is negative, fixing the
implementable direction as low jump beta long and high jump beta short.

## Bounded Price-Native Translation

The source's aggregate-jump series comes from stock-index option data via
Cremers, Halling, and Weinbaum (2015). Darwinex CFD runtime has neither that
option surface nor a broad commodity-futures panel. Exact replication is
therefore impossible and is not claimed.

QM5_13147 constructs a deterministic realized common-energy proxy from native
XTIUSD.DWX and XNGUSD.DWX completed D1 returns:

```text
formation = 252 synchronized completed D1 returns
w_i       = inverse_vol_i / sum(inverse_vol)
energy_d  = w_XTI * r_XTI,d + w_XNG * r_XNG,d
jump_d    = energy_d - mean(energy) when
            abs(energy_d - mean(energy)) >= 2.0 * sample_sd(energy), else 0

r_i,d = alpha_i + beta_energy_i * energy_d
                  + beta_jump_i * jump_d + epsilon_i,d
```

Require at least six realized jump days, buy the lower `beta_jump` leg, short
the higher leg, split fixed package risk equally, and hold to the next broker
month. The two-name factor, endogeneity, D1 threshold, futures/CFD basis, and
option-to-realized substitution are binding Q02 kill risks.

## Source Evidence Boundary

- The source ranks at least six of 26 collateralized futures. QM ranks only
  two continuous CFDs, so the source diversification and cross-sectional
  inference do not transfer.
- The source jump factor is option-derived and equity-market-wide. QM uses an
  endogenous realized energy factor. No source return, alpha, significance,
  drawdown, transaction-cost result, or correlation value is inherited.
- The primary sample ends in 2015. QM's 2017+ DWX window is out of sample.
- D1 standardized extremes are a coarse jump proxy. They do not distinguish
  discontinuous jumps from large continuous moves.
- Opposite-side equal fixed-risk legs reduce common energy direction but do
  not establish dollar, beta, volatility, factor, or realized neutrality.

## Non-Duplicate Boundary

- `QM5_13132_energy-bab` ranks total Dimson beta to a continuous energy
  benchmark and inverse-beta sizes the package. It does not isolate extreme-
  day sensitivity or estimate an incremental jump coefficient.
- `QM5_13129_energy-rsj` ranks each leg's own upside-minus-downside realized
  semivariance. It has no common factor or two-regressor jump beta.
- `QM5_13118_energy-skew-rank`, `QM5_13130_xti-xng-lowmax`,
  `QM5_13131_energy-kurt-rank`, and `QM5_13143_energy-es-rank` sort marginal
  distribution shape or tail loss, not sensitivity to common energy jumps.
- `QM5_13133_energy-ivol` and `QM5_13145_energy-idmom` use residual dispersion
  or residual return after a continuous commodity factor, not jump exposure.
- XTI/XNG ratio, return-spread, compression, carry, trend, calendar, and
  incumbent `QM5_12567` RSI logic use different signals and horizons.

The canonical pre-allocation checker found no exact or fuzzy duplicate across
4,033 registry rows and 335 cards. Verdict: `CLEAN_PRE_ALLOCATION`.

## R1-R4

- R1 source: PASS. One peer-reviewed primary paper with DOI and complete
  institutional text, plus a peer-reviewed commodity-jump supplement.
- R2 mechanical: PASS. Fixed synchronized return count, fixed inverse-vol
  benchmark, locked two-sigma realized-jump definition, fixed OLS controls,
  source-directed rank, monthly renewal, hard stops, and lifecycle guards.
- R3 data: PASS for the disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX
  D1 history is sufficient; exact option-factor replication is unavailable.
- R4 allowability: PASS. Native OHLC arithmetic, ATR safety stops, calendar,
  deal history, and broker metadata only; no ML, banned indicator, external
  runtime feed, grid, martingale, pyramiding, or adaptive PnL fit.

## Author Claim

The primary paper concludes that "jump risk appears to be significantly
priced" (accepted manuscript p. 11). This motivates queue admission only; it
does not validate the QM realized-jump proxy or two-CFD carrier.

## Safety Boundary

No live setfile, T_Live path, AutoTrading action, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI change is authorized.
