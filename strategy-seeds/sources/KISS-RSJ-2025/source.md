---
source_id: KISS-RSJ-2025
title: Good volatility, bad volatility and the cross section of commodity returns
publisher: Finance Research Letters
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://oru.diva-portal.org/smash/record.jsf?pid=diva2:2013183
cards_extracted:
  - energy-rsj
---

# Kiss-Martins Commodity RSJ Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 explicitly directs one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete 12-page open-access published paper was read end to end,
  including the theory, daily-data construction, portfolio sorts, factor
  regressions, robustness tests, commodity list, and both appendices.
- Extraction is bounded to one strategy: the paper's monthly cross-sectional
  relative-signed-jump (RSJ) premium, translated to the registered Darwinex
  energy carriers `XTIUSD.DWX` and `XNGUSD.DWX`.

## Primary Citation

Kiss, Tamas, and Igor Ferreira Batista Martins (2025), "Good Volatility, Bad
Volatility and the Cross Section of Commodity Returns," *Finance Research
Letters* 86, Part D, article 108656, DOI
https://doi.org/10.1016/j.frl.2025.108656.

Open published manuscript:
https://www.diva-portal.org/smash/get/diva2%3A2013183/FULLTEXT01.pdf

## Relevant Source Locations

- Section 2, pp. 2-3: commodity hedging demand and asymmetric producer utility
  provide the structural link from upside/downside semivariance to futures
  risk premia.
- Section 3, pp. 2-4, Equations 1-4: 36-commodity universe, daily returns,
  monthly upside and downside realized semivariances, signed jump, and the
  scale-invariant `RSJ = (RV+ - RV-) / (RV+ + RV-)` measure.
- Section 4.1, pp. 4-5 and Table 1: end-of-month RSJ sorts, equal-weighted
  portfolios, one-month hold, and the negative relation between RSJ and next-
  month excess returns.
- Section 4.2, pp. 5-6 and Table 2: RSJ remains distinct after market, carry,
  momentum, value, volatility, and realized-skewness controls.
- Section 5, pp. 6-8 and Tables 3-5: quintile, sub-period, and sector-exclusion
  robustness checks.
- Appendix A, pp. 8-10: WTI crude oil and natural gas are explicit source
  instruments; RSJ is not fully spanned by the skewness factor.
- Appendix B, pp. 10-11: asymmetric hedger utility ties expected profits and
  hedging decisions to return semivariances.

## Bounded Mechanization

At the first tradable D1 bar of each broker month, the card reconstructs the
immediately preceding complete broker-calendar month of daily close-to-close
returns for XTI and XNG. For each leg it sums squared positive returns into
`RV+`, squared negative returns into `RV-`, and computes normalized RSJ. It
buys the lower-RSJ leg, shorts the higher-RSJ leg, splits fixed package risk
equally, and holds until the next month transition.

This is not a replication of the paper's 36-future tercile or quintile
portfolios. The two-CFD narrowing, continuous-CFD versus collateralized-futures
basis, equal-risk carrier, and broker-calendar month are explicit falsification
risks. No source return, Sharpe ratio, correlation, or transaction-cost result
is imported into the QM prior.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, oversold pullback, long-only
  state, or short holding period.
- Not `QM5_12733_xti-xng-xmom`: no past-return winner rank.
- Not `QM5_12840_xti-xng-rspread`: no rolling return-spread z-score fade.
- Not `QM5_12850_xti-xng-vcb`: no volatility-contraction channel breakout.
- Not `QM5_13089_xti-xng-carry`: no broker-swap rank.
- Not `QM5_13113_energy-mom-ivol`: no momentum or residual-volatility double
  screen.
- Not `QM5_13115_energy-samecal`: no historical same-calendar-month return.
- Not `QM5_13118_energy-skew-rank`: that EA estimates the third standardized
  moment over 12 months; RSJ uses one month of separately squared positive and
  negative returns. The primary paper explicitly tests and rejects subsumption
  of RSJ by realized skewness.
- Not `QM5_13120`, `QM5_13121`, `QM5_13123`, or `QM5_13126`: no long-horizon
  reversal, trend/momentum, value, or momentum/carry agreement signal.

Pre-allocation repository dedup verdict: `CLEAN` on 2026-07-11.

## R1-R4

- R1 single source: PASS. One peer-reviewed paper, DOI, and institutional
  open-access published manuscript.
- R2 mechanical: PASS. Fixed completed-month return window, explicit RSJ
  formula and rank direction, monthly rebalance, equal risk, ATR hard stops,
  stale close, and orphan repair.
- R3 data available: PASS with translation risk. Registered XTIUSD.DWX and
  XNGUSD.DWX D1 OHLC are sufficient; no futures chain or external feed is used.
- R4 deterministic/no ML: PASS. One position per registered magic/symbol, no
  adaptive PnL fit, ML, external runtime data, grid, martingale, or pyramiding.
