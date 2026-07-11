---
source_id: HE-SALIENCE-2025
title: Salience Theory and the Returns of Commodity Futures
publisher: Author-uploaded academic preprint
source_type: academic_preprint_primary
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://doi.org/10.13140/RG.2.2.26815.83364
cards_extracted:
  - energy-sal-rank
---

# He et al. Commodity Salience Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity or energy card, build, and Q02 enqueue.
- The complete 52-page author-uploaded February 2025 paper was read end to
  end, including the measure construction, universe, controls, portfolio
  sorts, robustness tests, mechanism tests, asset-pricing tests, tables,
  appendices, and references.
- The monthly high-minus-low salience spread is the sole mechanical strategy.
  The control-variable sorts, macro-state splits, PCA/RP-PCA, and stochastic
  discount-factor tests are explanatory analyses, not separate entry rules.
- The paper is a primary academic working paper, not a peer-reviewed result.
  Its preprint status is preserved as an explicit Q02 kill risk. Cosemans and
  Frehen (2021), the peer-reviewed source for the salience-weight method, is a
  methodology supplement and does not supply the commodity direction.

## Primary Citation

He, Zhongda; Jia, Yuecheng; Shen, Mi; and Yang, Yuqing (2025), "Salience
Theory and the Returns of Commodity Futures," author-uploaded preprint dated
2025-02-03. DOI: https://doi.org/10.13140/RG.2.2.26815.83364.

Author-uploaded full text:
https://www.researchgate.net/publication/388633155_Salience_Theory_and_the_Returns_of_Commodity_Futures

Method supplement:
Cosemans, Mathijs and Frehen, Rik (2021), "Salience Theory and Stock Prices:
Empirical Evidence," *Journal of Financial Economics* 140, 460-483;
https://ssrn.com/abstract=2887956.

## Relevant Source Locations

- Section 2.2, Equations (2)-(5): daily salience, rank-based probability
  distortion, `theta=0.1`, `delta=0.7`, and the covariance definition of ST.
- Section 2: the commodity universe includes light crude oil and natural gas;
  the daily reference payoff is the unweighted cross-sectional mean return.
- Section 3 and Table 1: contracts are sorted monthly; the factor is long the
  high-ST tercile and short the low-ST tercile for the next month.
- Table 4: five- through eight-week formation windows retain the positive
  direction; the baseline analyzed-month construction remains the card rule.
- Sections 4-6 and Tables 6-12: the authors test distinctness from volatility,
  IVOL, MAX, skew, reversal, basis, value, momentum, and carry and interpret
  high ST as compensated risk bearing.
- Appendix A, Tables A1-A5: variable definitions, correlations, alternative
  market states, and factor-spanning robustness.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each broker calendar month, use
only synchronized completed D1 simple returns from the immediately preceding
complete broker month for `XTIUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX`, and
`XAGUSD.DWX`. The source's 28-commodity cross-sectional reference payoff is
not available in the native runtime, so form one fixed four-CFD equal-weight
proxy on each common date:

    r_bar[d] = 0.25 * (r_XTI[d] + r_XNG[d] + r_XAU[d] + r_XAG[d])

For each traded energy leg `i`, calculate:

    sigma_i[d] = abs(r_i[d] - r_bar[d]) /
                 (abs(r_i[d]) + abs(r_bar[d]) + 0.1)

Rank the prior-month dates from most salient (`k=1`) to least salient (`k=S`).
With equal objective probabilities and `delta=0.7`, normalize:

    omega_i[d] = delta ^ k_i[d] /
                 mean(delta ^ k_i[all prior-month dates])

The characteristic is the population covariance:

    ST_i = cov_population(omega_i[d], r_i[d])

Buy the higher-ST energy leg and short the lower-ST energy leg. Target equal
dollar notional after broker volume rounding, bound the complete package with
`RISK_FIXED=1000`, attach frozen per-leg ATR hard stops, and close at the next
calendar-month transition.

This is a strict proxy-carrier falsification, not a replication. The source
sorts a broad exchange-traded futures universe; QM ranks two continuous CFDs
against a four-CFD average that includes both traded legs. Universe breadth,
benchmark endogeneity, CFD rolls and financing, timestamp synchronization,
rank ties, legging, rounding, and costs remain binding Q02 kill risks. No
source performance, drawdown, correlation, or cost statistic is imported.

## Non-Duplicate Boundary

- `QM5_13118_energy-skew-rank` uses the raw standardized third moment; ST uses
  rank-normalized payoff salience and covariance with the asset return.
- `QM5_13129_energy-rsj` uses upside-minus-downside realized semivariance;
  ST is neither a variance decomposition nor a signed-jump statistic.
- `QM5_13130_xti-xng-lowmax` ranks extreme daily returns directly; ST weights
  every prior-month date by distance from the same-day commodity reference.
- `QM5_13131_energy-kurt-rank` ranks the fourth standardized moment; ST is a
  context-relative probability distortion and not tail thickness.
- `QM5_13133_energy-ivol` ranks market-model residual dispersion; ST neither
  fits a regression nor ranks residual variance.
- `QM5_13139_energy-cv-rank`, `QM5_13140_energy-aliq-rank`, and
  `QM5_13141_energy-ie-rank` use variance/mean, return/activity, and residual
  exceedance-frequency transforms respectively; none calculate salience
  ranks or salience-weight covariance.
- `QM5_12567_cum-rsi2-commodity` is short-horizon long-only RSI pullback;
  this card is monthly, opposite-side, indicator-free, and paired.

The canonical dedup checker returned fuzzy name-only matches to the CV, IE,
and value rank cards. Manual input, transform, direction, window, and lifecycle
review found no shared mechanic. Verdict: `CLEAN_AFTER_MANUAL_REVIEW` before
allocation.

## R1-R4

- R1 source: PASS with disclosure. Complete, author-uploaded academic primary
  source plus a peer-reviewed JFE methodology supplement; the commodity paper
  remains a non-peer-reviewed preprint and is not upgraded to Tier A.
- R2 mechanical: PASS. Fixed one-complete-month panel, fixed theta/delta,
  deterministic salience ranks, population covariance, high-minus-low rank,
  monthly renewal, sizing guard, hard stops, stale exit, deal-history guard,
  and orphan cleanup are deterministic.
- R3 data: PASS with explicit proxy risk. Registered XTI/XNG/XAU/XAG native D1
  histories supply the bounded panel; XAU/XAG are read-only.
- R4 deterministic/no ML: PASS. No external feed, PCA, density fit, banned
  indicator, ML, grid, martingale, pyramiding, or adaptive PnL fit.
