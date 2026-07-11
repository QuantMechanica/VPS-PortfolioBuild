---
source_id: SHPAK-IDMOM-2017
title: Idiosyncratic Momentum in Commodity Futures
publisher: Cross Border Benefits Alliance-Europe Review / SSRN
source_type: complete_academic_working_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://www.cbba-europe.eu/wp-content/uploads/2018/07/CBBA-Europe-review_July-2018.pdf
cards_extracted:
  - energy-idmom
---

# Shpak-Human-Nardon Idiosyncratic-Momentum Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 authorizes one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The bounded primary source is Shpak, Human, and Nardon, "Idiosyncratic
  Momentum in Commodity Futures," the complete article on pp. 56-85 of the
  July 2018 *Cross Border Benefits Alliance-Europe Review*, also posted as
  SSRN 3035397.
- The article was reviewed end to end: preamble, theory, data, equations,
  portfolio construction, factor definitions, all return tables, robustness,
  discussion, conclusion, and references.
- This packet extracts one rule only: the source-best 11-month formation,
  one-month holding idiosyncratic-momentum long-short construction.

## Primary Citation

Shpak, Iuliia; Human, Ben; and Nardon, Andrea (2017/2018),
"Idiosyncratic Momentum in Commodity Futures," SSRN 3035397 and *Cross Border
Benefits Alliance-Europe Review*, July 2018, pp. 56-85.

- Complete publication:
  https://www.cbba-europe.eu/wp-content/uploads/2018/07/CBBA-Europe-review_July-2018.pdf
- SSRN record: https://ssrn.com/abstract=3035397
- DOI record: https://doi.org/10.2139/ssrn.3035397

## Relevant Source Locations

- pp. 56-60: hypothesis, commodity-specific residual momentum, implementation
  motivation, long-short versus long-only results, and limitations.
- pp. 64-65: 28-future universe, including WTI and natural gas, roll-adjusted
  returns, factor data, and sample construction.
- pp. 65-69: ranking/holding mechanics, equal weights, equations 2-4, the
  instruction not to subtract estimated alpha from the ranking residual, and
  cumulative residual return as the winner/loser score.
- pp. 74-75: factor-selection evidence and the source's market, term-structure,
  and size factor set.
- pp. 76-81: long-short and long-only idiosyncratic-momentum results,
  concentrated sorts, robustness across horizons, and the strongest 11/1
  formation/holding combination.
- pp. 82-85: comparative risk/return, correlation, conclusion, theory, and
  source limitations.

## Source Rule

For each commodity i and month t, estimate exposure to systematic commodity
factors, then define a ranking residual without subtracting the fitted
intercept:

    residual_i,t = return_i,t - beta_i * factor_return_t

For the source's multiple-factor model the beta term is a vector product. Sum
the monthly ranking residuals over J months, rank contracts cross-sectionally,
buy the high-residual-momentum group, short the low group, and hold for K
months. The article examines J and K from 1 to 24/12 months and identifies
J=11, K=1 as the highest-return construction for both total and idiosyncratic
momentum.

## Bounded QM Translation

The native-DWX carrier cannot recreate the source's term-structure and size
factors without futures-curve and open-interest data. It therefore performs a
strict price-only falsification using the source-recognized commodity-market
factor:

1. On the first tradable XTIUSD.DWX D1 bar of broker month t, reconstruct the
   eleven completed monthly log returns for XTI, XNG, XAU, and XAG.
2. Set the monthly market proxy to the equal-weight return of those four fixed
   registered CFDs.
3. For XTI and XNG separately, fit one closed-window OLS beta to that market
   proxy across the eleven observations.
4. Following source equation 3, do not subtract fitted alpha from the ranking
   residual; sum `r_i - beta_i * r_factor` over the eleven months.
5. Buy the higher-score energy leg, short the lower-score leg, and hold the
   paired package to the next broker-month transition.

The carrier preserves the 11/1 cadence, cumulative residual-return rank,
winner-minus-loser direction, and equal opposite-side package. It substitutes
one fixed four-CFD market factor for the source's broader factors and narrows
28 futures to two traded energy CFDs. It is not a paper replication.

## Evidence Boundary

- The primary item is a complete named academic working paper/professional
  research publication, not a peer-reviewed finance-journal article. Source
  quality is B and stays a Q02 kill risk.
- The source's futures series include explicit roll mechanics, collateral and
  broader diversification. Darwinex continuous CFDs do not reproduce them.
- The paper's baseline residualization uses market, term-structure, and size
  factors. Only the price-native market component is available without an
  external runtime feed. The missing factors are not approximated or invented.
- A two-name rank always chooses a side even when scores are close. This is a
  narrow carrier, not the source's quartile or concentrated portfolio.
- Source returns, Sharpe ratios, significance, drawdowns, costs, and
  correlations are not imported as QM expectations or portfolio claims.

## Non-Duplicate Boundary

- QM5_12733 ranks recent raw XTI/XNG returns; it does not residualize a fixed
  commodity-market component.
- QM5_13113 requires raw momentum and residual-volatility rankings to agree;
  it never ranks cumulative residual return.
- QM5_13133 ranks idiosyncratic volatility alone.
- QM5_13141 ranks quadratic-factor residual tail asymmetry.
- QM5_13144 ranks one isolated t-11/t-10 monthly return.
- Carry, price-ratio, return-spread, value, calendar, RSI, and seasonality
  families use different inputs and transforms.

The canonical pre-allocation checker returned no exact or fuzzy match across
4,031 registry rows and 333 cards. Manual signal/input/window/direction review
verdict: CLEAN.

## R1-R4

- R1 source: PASS with qualification. Complete institutional/professional
  publication plus SSRN DOI; exact equations, universe, results, and
  limitations; quality tier B.
- R2 mechanical: PASS. Fixed 11 completed months, fixed four-CFD factor,
  closed-window beta, equation-3 residual score, monthly long-short renewal,
  hard stops, restart guard, and orphan cleanup.
- R3 data: PASS for queue admission. XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, and
  XAGUSD.DWX have registered native D1 routes; synchronized history is tested
  at Q02.
- R4 allowability: PASS. Price arithmetic, OLS, ATR safety stops, calendar,
  and broker metadata only; no ML, banned indicator, external runtime feed,
  grid, martingale, pyramiding, or adaptive PnL fit.

## Safety Boundary

No live setfile, T_Live path, AutoTrading action, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI change is authorized.
