---
source_id: FRAZZINI-BAB-2014
title: Betting Against Beta
publisher: Journal of Financial Economics / NBER
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://www.nber.org/papers/w16601
cards_extracted:
  - energy-bab
---

# Frazzini-Pedersen Betting Against Beta Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete 68-page September 2010 NBER conference draft was read end to
  end on 2026-07-11, including the theory, empirical method, proofs,
  robustness appendix, all tables, and all figures. The current official NBER
  record and 71-page working-paper wrapper were also checked.
- The paper contains one implementable strategy family: the monthly
  betting-against-beta factor. This packet extracts that family once into a
  bounded two-energy carrier; no additional card remains pending from the
  source.

## Primary Citation

Frazzini, Andrea, and Lasse Heje Pedersen (2014), "Betting Against Beta,"
*Journal of Financial Economics* 111(1), 1-25. DOI:
https://doi.org/10.1016/j.jfineco.2013.10.005.

Implementation-detail version: Frazzini and Pedersen, NBER Working Paper
16601, December 2010, DOI https://doi.org/10.3386/w16601. The September 2010
conference PDF used for the complete extraction is
https://conference.nber.org/confer/2010/BEf10/Frazzini.pdf.

## Relevant Source Locations

- pp. 2-6: leverage-constrained investors overpay for high-beta exposure,
  flattening the security market line.
- Equation 9, pp. 10-11: BAB is long low beta scaled to beta one and short
  high beta scaled to beta one, producing a zero-beta factor.
- pp. 14-17, Equations 14-15: futures data, one-year daily beta estimation,
  five lagged market-return terms, 0.5 shrinkage toward beta one, ascending
  beta rank, and monthly rebalance.
- p. 15: the commodity benchmark is a diversified equal-risk commodity
  portfolio.
- Table II: crude oil and natural gas are explicit source instruments.
- pp. 21-22 and Table IX: the source evaluates a commodity BAB portfolio, but
  the commodity-only result is statistically weak relative to diversified
  all-futures combinations.
- Appendix B and Tables B1-B7: beta-estimator, subperiod, volatility, size,
  and funding-liquidity robustness evidence.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each broker month, load 258
completed closes for XTI and XNG. Convert them to 257 simple daily returns,
use inverse one-year realized volatility to form a synchronized two-leg
equal-risk energy benchmark, and estimate each leg's Dimson beta from 252
observations with the current benchmark return plus five lags. Sum the six
OLS slopes and shrink the result halfway toward one.

The singleton low-beta portfolio is the lower of the two shrunk betas; the
singleton high-beta portfolio is the higher. Buy the low-beta leg and short
the high-beta leg. Scale intended notional exposure inversely to beta by
splitting the fixed stop-risk budget in proportion to each leg's relative
ATR divided by its beta. Reject a package when post-lot-rounding beta
exposures differ by more than the locked tolerance. Renew monthly.

This is a deliberately narrow carrier translation. The source uses 24
collateralized commodity futures and a diversified equal-risk benchmark;
QM uses two continuous CFDs and raw close-to-close returns because a daily
risk-free series and futures chain are unavailable at runtime. Q02 must treat
universe endogeneity, CFD financing/roll differences, and lot quantization as
falsification risks. No source return, alpha, Sharpe ratio, correlation, or
transaction-cost result is transferred to this carrier.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, pullback, long-only state, or
  short holding period.
- Not `QM5_12577`, `QM5_12724`, or `QM5_12862`: no XAU/XAG price ratio,
  residual spread, z-score, or breakout.
- Not `QM5_12733_xti-xng-xmom`: no trailing-return winner rank.
- Not `QM5_12840_xti-xng-rspread`: no return-spread mean reversion.
- Not `QM5_13089_xti-xng-carry`: no swap or term-structure proxy.
- Not `QM5_13113`, `QM5_13115`, `QM5_13118`, `QM5_13120`, `QM5_13121`,
  `QM5_13123`, `QM5_13126`, `QM5_13129`, `QM5_13130`, or `QM5_13131`:
  no momentum-IVOL agreement, same-calendar return, skew, momentum-reversal,
  trend filter, value, momentum-carry, semivariance, MAX, or kurtosis signal.
- Existing BAB EAs `QM5_1104`, `QM5_12396`, and `QM5_12403` trade equity
  indices; `QM5_1253_carver-lowbeta-rv` is registered only for indices and FX.
  None implements a two-leg XTI/XNG commodity BAB package.

The pre-allocation dedup tool produced one false fuzzy hit on
`energy-rsj_card.md` from the shared `energy-` token. Manual comparison found
zero overlap in formula, direction, data window, or package sizing. Verdict:
`CLEAN_AFTER_MANUAL_REVIEW` before atomic allocation.

## R1-R4

- R1 source: PASS. Peer-reviewed JFE article, official NBER working paper and
  DOI, complete paper and appendices reviewed.
- R2 mechanical: PASS. Fixed beta regression, shrinkage, rank, beta-matched
  sizing, monthly lifecycle, hard stops, and orphan handling.
- R3 data: PASS with translation risk. Registered XTI/XNG D1 OHLC and broker
  metadata suffice; no external runtime data is used.
- R4 deterministic/no ML: PASS. No ML, banned indicator, external feed, grid,
  martingale, pyramiding, or adaptive PnL fitting.
