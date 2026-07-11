---
source_id: FERNHOLZ-KOCH-RANK-2016
title: The Rank Effect for Commodities
publisher: Federal Reserve Bank of Dallas / arXiv
source_type: working_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://www.dallasfed.org/-/media/documents/research/papers/2016/wp1607.pdf
cards_extracted:
  - energy-rank-lmh
---

# Fernholz-Koch Commodity Rank-Effect Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 authorizes one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete Federal Reserve Bank of Dallas working paper and its arXiv
  revision were reviewed end to end, including the model, commodity universe,
  normalized-price construction, rank portfolios, robustness discussion, and
  conclusion.
- This packet extracts only the normalized-price rank effect. It does not
  authorize unrelated momentum, carry, value, seasonality, or futures-curve
  rules.

## Primary Citation

Fernholz, Ricardo T., and Christoffer Koch (2016), "The Rank Effect for
Commodities," Federal Reserve Bank of Dallas Working Paper 1607, revised
March 22, 2026.

Institutional paper:
https://www.dallasfed.org/-/media/documents/research/papers/2016/wp1607.pdf

Complete arXiv manuscript and revision history:
https://arxiv.org/abs/1607.07510

## Relevant Source Locations

- Abstract and Sections 1-2: a stationary relative-price distribution implies
  that lower-ranked commodity prices must grow faster, on average, than
  higher-ranked prices.
- Section 3: 30 commodity futures, explicitly including NYMEX crude oil and
  natural gas, are normalized to the same initial value and ranked by their
  normalized price.
- Section 3 portfolio construction: after a 20-trading-day wait, the source
  buys lower ranks and shorts higher ranks using equal dollar weights and
  daily rebalancing.
- Sections 3-4 and the conclusion: the low-minus-high result is evaluated
  against stock-market exposure, costs, subperiods, and alternative rank
  partitions.
- Appendix: the stochastic-rank model connects stationarity of the relative
  distribution to rank-conditioned growth rates.

## Source Rule

Choose one fixed start date, normalize each commodity future to the same
initial price, wait 20 trading days, then rank current normalized prices:

```text
normalized_i,t = price_i,t / price_i,anchor

long  = lower-ranked, lower-normalized-price commodities
short = higher-ranked, higher-normalized-price commodities
```

The source refreshes the cross-sectional ranks daily and applies equal dollar
weights to broad low- and high-rank groups.

## Bounded Low-Frequency Energy Translation

Darwinex runtime supplies two registered energy CFDs rather than the source's
30 collateralized futures. QM5_13148 therefore freezes a common observable
anchor and tests only the source's primitive rank direction:

```text
anchor_date       = 2017-01-03 broker date
effective_anchor  = first completed D1 close on/after anchor_date,
                    required within 7 calendar days and identical for both legs
warmup            = at least 20 completed D1 bars after the anchor close
normalized_XTI    = latest completed XTI close / XTI anchor close
normalized_XNG    = latest completed XNG close / XNG anchor close

if normalized_XTI < normalized_XNG: buy XTI, sell XNG
if normalized_XTI > normalized_XNG: sell XTI, buy XNG
if equal or invalid: remain flat
```

Ranks renew on the first tradable XTI D1 bar of each broker month, not daily.
One fixed-risk package is split equally and held to the next month, with
independent frozen ATR hard stops and restart-safe package guards.

## Source Evidence Boundary

- The paper uses 30 commodity futures, broad rank groups, equal dollar
  weights, and daily rebalancing. QM uses two continuous CFDs, equal fixed-risk
  halves, and monthly renewal. This is a severe narrowing, not a replication.
- The 2017-01-03 anchor is a predeclared Darwinex-history origin. It is not
  selected from PnL and must not move after Q02 results are observed.
- Continuous-CFD rolls, contract construction, financing, XNG gaps, and
  two-leg execution can dominate the rank signal.
- No source return, alpha, significance, drawdown, cost, turnover, or
  correlation statistic transfers to this carrier.
- Opposite sides reduce outright energy direction but do not establish dollar,
  beta, volatility, factor, or realized market neutrality.

## Non-Duplicate Boundary

- `QM5_13123_energy-val-rank` compares price with a rolling 54-66 month mean.
  It has a moving valuation anchor; this rule uses one immutable common origin
  and directly ranks normalized price levels.
- `QM5_12840_xti-xng-rspread` and other XTI/XNG spread builds z-score a rolling
  return or price ratio and require threshold crossings. This rule has no
  rolling spread, z-score, threshold, or mean estimate.
- `QM5_1129_gatev-pairs-trading-distance` uses a 252-bar formation window and
  standardized spread excursions. This rule never re-estimates its anchor or
  fades a standardized residual.
- Energy momentum, reversal, carry, trend, calendar, beta, tail, salience,
  liquidity, and idiosyncratic-factor builds use different inputs and ranking
  characteristics.
- `QM5_12567_cum-rsi2-commodity` is a two-day long-only RSI pullback; it has no
  paired normalized-price rank or monthly package.

The canonical pre-allocation checker returned five expected fuzzy matches on
the shared `energy-*-rank` slug family. Manual signal/input/window/direction
review resolved all five as distinct and found no fixed-origin normalized-
price low-minus-high energy basket.

## R1-R4

- R1 source: PASS. Complete named-author Federal Reserve working paper plus
  the complete arXiv manuscript; the non-peer-reviewed status is disclosed.
- R2 mechanical: PASS. Immutable anchor, bounded anchor gap, 20-bar warm-up,
  direct normalized-price comparison, locked low-minus-high direction,
  monthly renewal, hard stops, and lifecycle guards.
- R3 data: PASS for the disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX
  D1 histories cover the 2017 anchor and subsequent test interval.
- R4 allowability: PASS. Native closes, ATR safety stops, broker calendar,
  deal history, and contract metadata only; no ML, banned indicator, external
  runtime feed, grid, martingale, pyramiding, or adaptive PnL fit.

## Author Claim

The paper states that "lower-ranked, lower-priced assets must necessarily have
their prices grow more quickly" (Section 2). This motivates queue admission
only; it does not validate the two-CFD monthly carrier.

## Safety Boundary

No live setfile, T_Live path, AutoTrading action, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI change is authorized.
