---
source_id: KWON-KANG-YUN-WTI-WMOM1-2026
title: Pure one-week WTI return-sign momentum extraction
publisher: QuantMechanica governed extraction from peer-reviewed research
source_type: peer_reviewed_paper_extraction
status: approved_source_complete
approval_basis: decisions/2026-09-07_wti_pure_one_week_momentum_source_approval.md
created: 2026-09-07
created_by: Research+Development
uri: https://doi.org/10.1016/j.frl.2019.101306
cards_extracted:
  - wti-wmom1
---

# Pure One-Week WTI Return-Sign Momentum

## Complete-Read Record

Kwon, Kyung Yoon; Kang, Jangkoo; and Yun, Jaesun, *Weekly Momentum
in the Commodity Futures Market*, Finance Research Letters 35 (2020), 101306,
DOI `10.1016/j.frl.2019.101306`.

The complete 20-page accepted manuscript was retrieved on 2026-09-07 from the
University of Strathclyde institutional repository:
`https://pure.strath.ac.uk/ws/portalfiles/portal/91110414/Kwon_etal_FRL_2019_Weekly_momentum_in_the_commodity_futures_market.pdf`.
Retrieved PDF SHA-256:
`D768279A0B0F601216FFFA5C48A534939822E7C29B039169ADF0CA817B222F2C`.
All pages, including methodology, results, adverse boundaries, references, and
Tables 1-6, were read before approval.

## Source Findings

- The sample uses daily settlement prices for 32 US commodity futures from
  January 1979 through June 2015 and holds the nearest contract not expiring in
  the next month (pp. 3-4).
- Light sweet crude oil is explicitly one of seven energy contracts (Table 1,
  p. 14).
- The paper decomposes past 52-week returns into four non-overlapping formation
  periods. `CMOM1,1` uses only week `t-1` and trades in week `t` (p. 4).
- Portfolios buy the top commodity quintile and sell the bottom quintile; this
  is cross-sectional evidence, not an outright time-series WTI rule (p. 4).
- Weekly momentum earns 0.20% per week with t-statistic 4.49, and a 0.20%
  risk-adjusted intercept with t-statistic 4.30 (Table 2, p. 16).
- Weekly momentum remains robust after equity-momentum, carry, average-
  commodity, and hedging-pressure controls (pp. 5-7; Tables 2-4).
- The authors associate the first-week effect with speculative trend-following,
  while explicitly declining to claim a complete causal explanation (pp. 8-11).

## Adverse Evidence And Translation Boundary

The source does not publish a standalone WTI time-series backtest, continuous
CFD result, Monday-anchored broker-week implementation, ATR stop, fixed-dollar
risk, or transaction-cost result for this exact port. Cross-sectional ranking
creates relative long-short diversification absent from an outright WTI
position. The paper's futures roll rule cannot be recreated by XTIUSD.DWX.

Accordingly, source efficacy, risk-adjusted return, causality, neutrality, and
portfolio decorrelation do not transfer. Q02 must falsify density and economics;
Q09 alone may measure book correlation.

## Bounded Mechanization

At the first tradable D1 bar of a normalized Monday-anchored broker week,
aggregate the exact immediately preceding completed three-to-five-session week.
Use the chronologically first session open and final session close. Compute
`r = ln(week_close/week_open)`. Buy exact XTIUSD.DWX if `r>0`, sell if `r<0`,
and stay flat for equality or invalid state. Consume the week before fallible
gates, use one fixed-risk position with a frozen `3.5*ATR(20,D1)` stop, and
flatten at the first later week boundary.

This is the narrowest price-native time-series translation of `CMOM1,1`. It
adds no volatility, magnitude, body/range, range, moving-average, calendar,
event, inventory, volume, open-interest, or curve filter.

## Non-Duplicate Boundary

The deterministic checker scanned 4,855 registry rows, 1,468 cards, and 45
Strategy Wiki nodes and returned CLEAN. `QM5_13049` conditions one-week WTI
momentum on low volatility; `QM5_41092` conditions it on strict weekly body
dominance; later weekly WTI cards require multi-week sign or OHLC patterns.
Removing those load-bearing filters is the defining source-faithful identity,
not a parameter variation of them.

Verdict:
`DISTINCT_WTI_PURE_IMMEDIATELY_COMPLETED_WEEK_RETURN_SIGN_CONTINUATION`.

## R1-R4

- R1: `PASS_WITH_TIME_SERIES_PORT_RISK`; complete reputable peer-reviewed
  source, exact weekly horizon, WTI membership, and adverse evidence retained.
- R2: `PASS`; endpoints, sign, side, attempt, risk, stop, and lifecycle fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native WTI D1 data.
- R4: `PASS`; deterministic native arithmetic without ML or banned signals.

## Falsification Boundary

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, mixed energy-label
conventions, current-week leakage, wrong sign, repeated attempts, missing stop,
wrong weekly exit, or nondeterminism. No carrier, filter, side, threshold, risk,
or lifecycle rescue is authorized.
