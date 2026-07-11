---
source_id: SZYMANOWSKA-CV-2014
title: An Anatomy of Commodity Futures Risk Premia
publisher: The Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://onlinelibrary.wiley.com/doi/10.1111/jofi.12096
cards_extracted:
  - energy-cv-rank
---

# Szymanowska et al. Commodity CV Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete 45-page open paper was read end to end on 2026-07-11,
  including the theoretical decomposition, data, portfolio construction,
  regressions, robustness sections, appendices, tables, and bibliography.
- The coefficient-of-variation sort is the sole new native-data extraction.
  Basis, momentum, and term-premium families are already represented in V5;
  hedging pressure and maturity/roll legs require unavailable futures-chain or
  positioning data. No second card remains pending from this review.

## Primary Citation

Szymanowska, Marta; de Roon, Frans; Nijman, Theo; and van den Goorbergh, Rob
(2014), "An Anatomy of Commodity Futures Risk Premia," *The Journal of
Finance* 69(1), 453-482. DOI: https://doi.org/10.1111/jofi.12096.

Open full paper:
https://a.storyblok.com/f/331657/x/17e020bced/an-anatomy-of-commodity-futures-risk-premia-szymanowska-and-de-roon-and-nijman-and-van-den-goorbergh-2013.pdf

## Relevant Source Locations

- Data and portfolio-construction sections: 21 commodity futures across seven
  sectors, bimonthly observations, four cross-sectional portfolios, and a
  March 1986-December 2010 sample.
- PDF p. 20: higher spot-price volatility measured by coefficient of variation
  is associated with higher expected commodity-futures returns.
- Appendix B, PDF p. 30: CV uses variance scaled by mean return over months
  `t-36` through `t-1`; scaling by mean separates the volatility characteristic
  from momentum.
- Table III, PDF p. 40: the high-minus-low short-roll CV portfolios are
  positive across four maturities, but maturity and basis decompositions are
  material to interpretation.
- The paper's energy sector contains three futures. The QM carrier has only two
  continuous broker CFDs and cannot reproduce the source's maturity portfolios.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of January, March, May, July,
September, and November, reconstruct 37 completed broker month-end closes for
both XTI and XNG and calculate 36 monthly log returns. For each leg compute the
sample variance with denominator 35 and divide it by the absolute arithmetic
mean return. Buy the higher-CV leg, short the lower-CV leg, split fixed package
risk equally, and hold until the next bimonthly rebalance.

The absolute denominator is the deterministic, sign-safe coefficient-of-
variation translation: a negative mean must not turn a nonnegative risk
measure negative. A mean whose absolute value is at or below `1e-12`, missing
month, nonpositive variance, numerical tie, or invalid arithmetic stays flat.

This is a falsifiable two-energy-CFD carrier, not a replication. The source
ranks 21 collateralized futures, observes multiple maturities, and decomposes
spot and term premia. QM ranks two continuous CFDs without a futures curve.
No source return, alpha, correlation, drawdown, or transaction-cost statistic
is imported into the QM prior.

## Non-Duplicate Boundary

- `QM5_13123_energy-val-rank` ranks a 54-66 month historical-price ratio; this
  card ranks trailing monthly variance divided by absolute mean return.
- `QM5_13132_energy-bab` ranks market beta; this card has no covariance or beta.
- `QM5_13133_energy-ivol` ranks daily OLS residual volatility against a four-
  commodity factor; this card has no regression or read-only metal factor.
- `QM5_13118`, `QM5_13129`, and `QM5_13131` rank skewness, signed
  semivariance, and kurtosis; CV uses only the first two central moments.
- `QM5_13134_energy-vr-mom` is a single-WTI variance-ratio regime filter; this
  card is a paired cross-sectional level rank with no autocorrelation term.
- `QM5_12567_cum-rsi2-commodity` is short-horizon long-only RSI pullback logic;
  this card is bimonthly, symmetric long-short, and indicator-free.

The dedup checker produced a fuzzy slug match to `energy-val-rank` because both
names contain "energy" and "rank." Manual formula and code review found no
shared signal input, transformation, direction, or holding rule. Verdict:
`CLEAN_AFTER_MANUAL_REVIEW` before allocation.

## R1-R4

- R1 source: PASS. Peer-reviewed Journal of Finance article, DOI, publisher
  record, open full text, and complete source review.
- R2 mechanical: PASS. Fixed 36-month formula, odd-month bimonthly calendar,
  high-minus-low rank, equal fixed risk, hard stops, stale exit, deal-history
  guard, and orphan cleanup are deterministic.
- R3 data: PASS with explicit carrier risk. Registered XTI/XNG native D1 OHLC
  provides completed month-end closes; no external feed or futures chain.
- R4 deterministic/no ML: PASS. No ML, banned indicator, grid, martingale,
  pyramiding, adaptive PnL fit, or external runtime data.
