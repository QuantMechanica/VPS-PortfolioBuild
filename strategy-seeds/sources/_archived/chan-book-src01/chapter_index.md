# SRC01 — Chapter Index (publisher TOC, not body claims)

> **Source of TOC:** O'Reilly Media catalog listing for the book's eBook ISBN 978-1-118-74691-2.
> **URL:** https://www.oreilly.com/library/view/algorithmic-trading-winning/9781118746912/
> **Fetched:** 2026-04-27 by Research Agent for SRC01 scaffolding.
> **Scope of this file:** chapter and section *titles only* — no body content, no performance claims, no methodology details. Body claims require the actual book and will be added per-card during extraction.

The TOC was cross-checked against the Wiley product page metadata (ISBN 978-1-118-46014-6) and Wiley Online Library DOI `10.1002/9781118676998`; the section structure below reflects the O'Reilly listing verbatim.

## Front matter

- Cover
- Half Title
- Series Page
- Title Page
- Copyright Page
- Dedication
- Preface — *The Motive*; *A Note about Sources and Acknowledgments*

## Chapter 1 — Backtesting and Automated Execution

- The Importance of Backtesting
- Common Pitfalls of Backtesting
- Statistical Significance of Backtesting: Hypothesis Testing
- When Not to Backtest a Strategy
- Will a Backtest Be Predictive of Future Returns?
- Choosing a Backtesting and Automated Execution Platform

**Strategy-extraction expectation:** likely meta-only (process & methodology). Probably zero candidate cards. Read for citation calibration; flag any in-line strategy examples.

## Chapter 2 — The Basics of Mean Reversion

- Mean Reversion and Stationarity
- Cointegration
- Pros and Cons of Mean-Reverting Strategies

**Strategy-extraction expectation:** foundational concepts. Methodology rather than mechanical strategies. Possibly 0 cards; depends on whether Chan presents a worked-example strategy.

## Chapter 3 — Implementing Mean Reversion Strategies

- Trading Pairs Using Price Spreads, Log Price Spreads, or Ratios
- Bollinger Bands
- Does Scaling-in Work?
- Kalman Filter as Dynamic Linear Regression
- Kalman Filter as Market-Making Model
- The Danger of Data Errors

**Strategy-extraction expectation:** highest density chapter. Multiple candidate cards likely (pairs spread, Bollinger, Kalman regression, Kalman market-making). v0-filter risk: Kalman market-making may fall outside V5 scalping discipline — flag for CEO if so. Pairs and Bollinger are squarely in scope.

## Chapter 4 — Mean Reversion of Stocks and ETFs

- The Difficulties of Trading Stock Pairs
- Trading ETF Pairs (and Triplets)
- Intraday Mean Reversion: Buy-on-Gap Model
- Arbitrage between an ETF and Its Component Stocks
- Cross-Sectional Mean Reversion: A Linear Long-Short Model

**Strategy-extraction expectation:** ETF Pairs/Triplets, Buy-on-Gap, Cross-Sectional Long-Short are candidate cards. Stock-component arbitrage probably fails the V5 v0 filter (requires equities universe + custom data — Darwinex MT5 native data only per `V5_FRAMEWORK_DESIGN.md` line 32). Stock pairs may fail too — flag.

## Chapter 5 — Mean Reversion of Currencies and Futures

- Trading Currency Cross-Rates
- Rollover Interests in Currency Trading
- Trading Futures Calendar Spread
- Trading Futures Intermarket Spreads

**Strategy-extraction expectation:** currency cross-rates and rollover-aware carry are direct V5-eligible candidates. Futures calendar / intermarket spreads need custom-data feasibility check at extraction time (Darwinex symbol-set coverage).

## Chapter 6 — Interday Momentum Strategies

- Tests for Time Series Momentum
- Time Series Strategies
- Extracting Roll Returns through Future versus ETF Arbitrage
- Cross-Sectional Strategies
- Pros and Cons of Momentum Strategies

**Strategy-extraction expectation:** time-series momentum and cross-sectional momentum likely yield candidate cards. Future-vs-ETF roll-return arbitrage probably fails V5 v0 (mixed-instrument arbitrage outside Darwinex MT5 single-broker scope) — flag.

## Chapter 7 — Intraday Momentum Strategies

- Opening Gap Strategy
- News-Driven Momentum Strategy
- Leveraged ETF Strategy
- High-Frequency Strategies

**Strategy-extraction expectation:** Opening Gap is a strong candidate. News-Driven Momentum is in scope but needs news-compliance variant per `PIPELINE_PHASE_SPEC.md` P8. Leveraged ETF requires US ETF universe — flag for v0-filter likely-fail. High-Frequency may trigger V5 scalping discipline (P5b VPS-realistic latency stress mandatory) — flag.

## Chapter 8 — Risk Management

- Optimal Leverage
- Constant Proportion Portfolio Insurance
- Stop Loss
- Risk Indicators

**Strategy-extraction expectation:** meta-only. CPPI and Optimal Leverage may inform `framework/include/QM/QM_RiskSizer.mqh` improvements but do not produce Strategy Cards. Stop Loss and Risk Indicators feed framework-level risk modules, not strategy cards. Probably 0 cards.

## Back matter

- Conclusion
- Bibliography
- About the Author
- About the Website
- Index

The book's companion website (referenced under "About the Website") historically distributed MATLAB code samples. **Out of scope** for V5 extraction — V5 strategies are MQL5-implemented per `V5_FRAMEWORK_DESIGN.md` § 4-Module Pattern; MATLAB code is reference-only and not citable for parameter sketches.

## Index quality note

When source text arrives, Research will recompute page ranges for every section listed above and replace the section-only references with `chapter N § Title, page P-Q` form. The Strategy Card `## 1. Source` block requires that combined chapter + page form per `source.md` § 4.

## Aggregate expectation

Given the chapter structure, Research's pre-extraction estimate is **6-12 candidate Strategy Cards** before v0-filter, with **3-7** surviving v0 (mechanical / no-ML / Darwinex-data-feasible / news-compliance-compatible). This is a sketch, not a target — the actual number depends on Chan's own scope and how many strategies the book treats as full mechanical recipes versus pedagogical examples.
