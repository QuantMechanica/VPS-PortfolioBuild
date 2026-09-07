---
source_id: KWON-KANG-YUN-WTI-WMOM42-2026
title: WTI skipped-recent-week three-week momentum extraction
publisher: QuantMechanica governed extraction from peer-reviewed research
source_type: peer_reviewed_paper_extraction
status: approved_source_complete
approval_basis: decisions/2026-09-07_wti_skipped_week_three_week_momentum_source_approval.md
created: 2026-09-07
created_by: Research+Development
uri: https://doi.org/10.1016/j.frl.2019.101306
cards_extracted:
  - wti-wmom42
---

# WTI Skipped-Recent-Week Three-Week Momentum

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
- In each week `t`, the paper constructs `CMOM4,2` from the cumulative return
  over weeks `t-4` through `t-2`; the immediately recent week `t-1` is excluded
  and the resulting ranked portfolio is held in week `t` (p. 4).
- Portfolios buy the top commodity quintile and sell the bottom quintile; this
  is cross-sectional evidence, not an outright time-series WTI rule (p. 4).
- `CMOM4,2` earns 0.16% per week with t-statistic 2.70 in the source sample and
  has a positive risk-adjusted intercept (Table 2, p. 16).
- The authors report that `CMOM4,2` is largely captured by `CMOM1,1`; when the
  former is regressed on the latter, its intercept is insignificant (p. 6).

## Adverse Evidence And Translation Boundary

The source does not publish a standalone WTI time-series backtest, continuous
CFD result, Monday-anchored broker-week implementation, ATR stop, fixed-dollar
risk, or transaction-cost result for this exact port. Its cross-sectional
ranking creates relative long-short diversification absent from an outright
WTI position. The paper explicitly says the monthly-horizon signal is largely
spanned by its one-week signal, so this sibling is weaker source evidence than
`CMOM1,1`. The futures roll rule cannot be recreated by `XTIUSD.DWX`.

Accordingly, efficacy, risk-adjusted return, causality, independence from the
one-week sibling, and portfolio decorrelation do not transfer. Q02 must
falsify density and economics; Q09 alone may measure realized book correlation.

## Bounded Mechanization

At the first tradable D1 bar of a normalized Monday-anchored broker week `t`,
reconstruct exactly the four immediately preceding completed broker weeks.
Discard week `t-1`; aggregate the chronologically first open of week `t-4` to
the final close of week `t-2`. Compute `r=ln(close[t-2]/open[t-4])`. Buy exact
`XTIUSD.DWX` if `r>0`, sell if `r<0`, and stay flat for equality or invalid
state. Consume the week before fallible gates, use one fixed-risk position with
a frozen `3.5*ATR(20,D1)` stop, and flatten at the next week boundary.

This is the narrow price-native time-series translation of `CMOM4,2`. It adds
no volatility, magnitude, body/range, moving-average, calendar, event,
inventory, volume, open-interest, or curve filter.

## Non-Duplicate Boundary

The deterministic checker scanned 4,856 registry rows and 1,469 cards. Its only
fuzzy match was expected same-paper sibling `QM5_41375_wti-wmom1`; the external
wiki root was unavailable and is recorded fail-closed in the receipt. Manual
review distinguishes the identities:

- `QM5_41375` forms on week `t-1` only; this candidate must exclude `t-1` and
  forms cumulatively on exactly `t-4..t-2`.
- `QM5_20284_wti-skip1-trend` is a monthly twelve-month trend rule that skips
  the most recent month, not a weekly three-week formation/one-week hold.
- WTI one-month, two-month, multi-week pattern, calendar, event, and statistical
  regime cards use different horizons, endpoints, or state.

Verdict:
`DISTINCT_WTI_CMOM42_EXACT_T_MINUS_4_TO_T_MINUS_2_SKIP_T_MINUS_1_WEEKLY_CONTINUATION`.

## R1-R4

- R1: `PASS_WITH_TIME_SERIES_PORT_RISK`; one complete peer-reviewed source,
  exact formation/holding horizon, explicit WTI membership, and adverse
  evidence retained.
- R2: `PASS`; endpoints, excluded week, sign, side, attempt, risk, stop, and
  lifecycle fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native WTI D1 data.
- R4: `PASS`; deterministic native arithmetic without ML or banned signals.

## Falsification Boundary

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, mixed energy-label
conventions, inclusion of week `t-1`, wrong formation endpoints, wrong sign,
repeated attempts, missing stop, wrong weekly exit, or nondeterminism. No
carrier, filter, side, threshold, risk, or lifecycle rescue is authorized.
