---
source_id: YIYI-ALIQ-2025
title: Commodity Futures Characteristics and Asset Pricing Models
publisher: Journal of Futures Markets
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://onlinelibrary.wiley.com/doi/10.1002/fut.22559
cards_extracted:
  - energy-aliq-rank
---

# Qin et al. Commodity Illiquidity Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity or energy card, build, and Q02 enqueue.
- The complete open prepublication paper was read end to end on 2026-07-11,
  including the introduction, characteristic definitions, portfolio sorts,
  pairwise correlations, IPCA tests, panel regressions, robustness material,
  appendices, tables, and bibliography.
- Amihud illiquidity is the sole extraction from this review. Momentum,
  value/basis, beta, idiosyncratic volatility, skewness, semivariance, maximum
  return, kurtosis, variance ratio, expected shortfall, and coefficient of
  variation already have V5 implementations or materially overlapping cards.

## Primary Citation

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity Futures
Characteristics and Asset Pricing Models," Journal of Futures Markets 45(3),
176-207. DOI: https://doi.org/10.1002/fut.22559.

Publisher record:
https://onlinelibrary.wiley.com/doi/10.1002/fut.22559

Open full paper:
https://acfr.aut.ac.nz/__data/assets/pdf_file/0006/927429/commodity_20240701.pdf

## Relevant Source Locations

- Data section: 34 commodity futures across energy, grains and oilseeds,
  livestock, metals, and softs from January 1981 through June 2022.
- Portfolio construction: characteristics formed with information available
  in month t-1, equal-weighted top and bottom 30 percent portfolios, and
  month-t returns.
- Appendix A: ALIQ is the average, over months t-12 through t-1, of the daily
  absolute return divided by dollar volume and multiplied by 1,000,000.
- Table 3: the broad-universe one-way ALIQ high-minus-low portfolio has a
  positive reported annualized mean and t-statistic, based on 498 months.
- Characteristic-correlation table: ALIQ has low pairwise correlation with
  MOM12, IVOL, skewness, MAX, expected shortfall, and basis in the source
  universe.
- IPCA table: ALIQ is not a statistically significant instrument for latent
  factor loadings. The transparent one-way sort, not the IPCA model, is the
  only mechanized source result.
- Appendix D: panel regressions provide an additional positive next-month
  return association, but are not imported as a performance prior.

## Bounded Mechanization

At the first tradable XTIUSD.DWX D1 bar of each broker calendar month, use the
prior 12 completed calendar months of D1 history for XTIUSD.DWX and XNGUSD.DWX.
For every completed daily bar in those months calculate:

    daily_aliq = abs(log(close_t / close_t_minus_1))
                 / tick_volume_t * 1,000,000

Average the valid daily measures for each leg. Buy the higher-ALIq energy leg,
short the lower-ALIq leg, split fixed package risk equally, and hold until the
next calendar-month transition.

MT5 tick volume is explicitly an activity proxy. It is not exchange dollar
volume and this two-CFD carrier is not a replication. The source ranks 34
exchange-traded futures and uses dollar volume; QM ranks two continuous broker
CFDs using quote-tick counts. Q02 must kill the translation if the proxy,
narrow cross-section, history, costs, or trade density do not survive.

No source return, alpha, drawdown, correlation, or transaction-cost statistic
is imported into the QM prior. The source's IPCA machinery is excluded from
the signal and from runtime.

## Non-Duplicate Boundary

- QM5_10330_illiq-rev is an H1 single-symbol liquidity-shock reversal using
  broker spread and tick-volume percentiles. This card is a monthly
  cross-sectional high-minus-low illiquidity premium and never fades a shock.
- cs-spread-rev uses the Corwin-Schultz high-low spread estimator and a
  short-run reversal. This card uses daily absolute return per activity unit,
  ranks two energy legs, and holds for a month.
- QM5_13123, QM5_13132, QM5_13133, QM5_13118, QM5_13129, QM5_13130,
  QM5_13131, QM5_13134, QM5_13139 rank value, beta, IVOL, skewness, signed
  semivariance, MAX, kurtosis, variance-ratio momentum, and coefficient of
  variation. None divides absolute daily return by volume or activity.
- QM5_12567 is short-horizon long-only RSI pullback logic. This card is
  indicator-free, monthly, and symmetric long-short.

The canonical repository dedup checker found no exact or fuzzy match for slug
energy-aliq-rank or strategy ID YIYI-ALIQ-2025_XTI_XNG_S01. Manual mechanic
review found no shared signal transformation, direction rule, or holding rule.
Verdict: CLEAN before allocation.

## R1-R4

- R1 source: PASS. Peer-reviewed Journal of Futures Markets paper, DOI,
  publisher record, open full text, and complete source review.
- R2 mechanical: PASS. Fixed 12-month ALIQ proxy, calendar-month rank,
  high-minus-low direction, equal fixed risk, hard stops, stale exit,
  deal-history guard, and orphan cleanup are deterministic.
- R3 data: PASS with binding proxy risk. Registered XTI/XNG native D1 bars
  provide closes and tick volume, but tick volume is not source dollar volume.
- R4 deterministic/no ML: PASS. No IPCA, PCA, regression, ML, banned
  indicator, grid, martingale, pyramiding, adaptive PnL fit, or external
  runtime data.
