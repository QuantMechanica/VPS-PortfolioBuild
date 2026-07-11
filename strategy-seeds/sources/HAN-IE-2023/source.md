---
source_id: HAN-IE-2023
title: Is idiosyncratic asymmetry priced in commodity futures?
publisher: Journal of Financial Research
source_type: peer_reviewed_open_access_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://doi.org/10.1111/jfir.12339
cards_extracted:
  - energy-ie-rank
---

# Han et al. Commodity Idiosyncratic-Asymmetry Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity or energy card, build, and Q02 enqueue.
- The complete open-access 24-page published paper was read end to end,
  including the theory, asymmetry definitions, data, characteristic tests,
  portfolio sorts, factor tests, robustness appendices, tables, and references.
- The distribution-based idiosyncratic-asymmetry characteristic (`IE`) is the
  sole extraction. The paper's traditional residual-skewness comparison is not
  extracted because `QM5_13118_energy-skew-rank` already tests the stronger
  source-backed raw-skew family, and the factor-pricing regressions are not an
  executable entry rule.

## Primary Citation

Han, Yufeng; Mo, Xuan; Su, Zhi; and Zhu, Yifeng (2023), "Is idiosyncratic
asymmetry priced in commodity futures?", *Journal of Financial Research*
46(3), 875-898. DOI: https://doi.org/10.1111/jfir.12339.

Institutional open-access copy:
https://ninercommons.charlotte.edu/record/3941

Published open PDF:
https://ninercommons.charlotte.edu/nanna/record/3941/files/hanyuf_etal_idias_ir_2023.pdf?registerDownload=1&version=1&withMetadata=0&withWatermark=0

## Relevant Source Locations

- Section 2.1 and Equation (1): `IE` is the probability of a standardized
  residual above +0.5 minus the probability below -0.5.
- Section 2.1: daily commodity returns are residualized on an intercept, the
  commodity-market return, and its square using six months of daily returns.
- Section 3.1 and Table 1: WTI crude oil and natural gas are explicit members
  of the four-contract energy sector in the 27-future universe.
- Section 5.1: contracts are ranked monthly; the low-IE group is held long and
  the high-IE group short for the following month.
- Sections 4.1, 5.1-5.3, and 6: the negative characteristic relation survives
  the paper's controls and the authors distinguish IE from raw skewness.
- Appendix A: the six-month residualization window and characteristic
  definitions are restated.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each broker calendar month, use
only synchronized completed D1 returns from the preceding six complete broker
months. The source's S&P GSCI series is not available in the Darwinex-native
runtime, so form one fixed, equal-weight commodity-market proxy from registered
`XTIUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX`, and `XAGUSD.DWX` daily returns.

For each traded energy leg, estimate by ordinary least squares:

    r_i[d] = alpha_i + beta_i * r_m[d] + gamma_i * r_m[d]^2 + epsilon_i[d]

Center the residuals, standardize them to unit population standard deviation,
then calculate the empirical distribution statistic:

    IE_i = count(z_i >= +0.5) / N - count(z_i <= -0.5) / N

Buy the lower-IE energy leg and short the higher-IE leg. Target equal dollar
notional after broker volume rounding, bound the whole package with
`RISK_FIXED=1000`, place frozen per-leg ATR hard stops, and close at the next
calendar-month transition.

This is a falsifiable two-energy-CFD carrier, not a replication. The source
ranks 27 exchange-traded futures against the S&P GSCI. QM ranks two continuous
CFDs against a four-CFD equal-weight proxy that includes the traded legs.
Benchmark endogeneity, breadth loss, CFD rolls/financing, synchronized history,
rounding, and costs remain binding Q02 kill risks. No source return, alpha,
drawdown, correlation, or cost statistic is imported.

## Non-Duplicate Boundary

- `QM5_13118_energy-skew-rank` ranks the raw third standardized moment. This
  card first removes linear and squared commodity-market exposure and ranks a
  distribution-tail probability difference; the source finds IE distinct from
  traditional skewness.
- `QM5_13133_energy-ivol` ranks the standard deviation of linear-factor OLS
  residuals. This card uses a quadratic factor regression and the signs of
  standardized residual tails; residual magnitude alone is not the signal.
- `QM5_13139_energy-cv-rank` ranks 36-month variance divided by absolute mean
  return. This card uses six months of daily residual tail frequencies.
- `QM5_13140_energy-aliq-rank` ranks absolute return per tick-volume proxy.
  This card never reads volume.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only RSI pullback.
  This card is monthly, paired, indicator-free, and symmetric long-short.

The canonical dedup checker returned only fuzzy name matches to
`energy-cv-rank` and `energy-val-rank`. Manual formula, direction, input,
window, and lifecycle review found no shared mechanic. Verdict:
`CLEAN_AFTER_MANUAL_REVIEW` before allocation.

## R1-R4

- R1 source: PASS. Peer-reviewed, open-access Journal of Financial Research
  paper with DOI, institutional repository, and complete source review.
- R2 mechanical: PASS. Fixed six-month OLS design, fixed +/-0.5 residual-tail
  statistic, low-minus-high rank, monthly renewal, sizing guard, hard stops,
  stale exit, deal-history guard, and orphan cleanup are deterministic.
- R3 data: PASS with explicit proxy risk. Registered XTI/XNG/XAU/XAG native D1
  histories supply the bounded close series; XAU/XAG are read-only.
- R4 deterministic/no ML: PASS. No density fit, GSCI/external feed, ML, banned
  indicator, grid, martingale, pyramiding, or adaptive PnL fit.
