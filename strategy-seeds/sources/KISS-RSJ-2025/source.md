---
source_id: KISS-RSJ-2025
title: Good volatility, bad volatility and the cross section of commodity returns
publisher: Finance Research Letters
source_type: peer_reviewed_paper
status: cards_ready
approval_basis: OWNER commodity-sleeve missions 2026-07-11 and 2026-08-06
created: 2026-07-11
created_by: Research
last_updated: 2026-08-06
uri: https://oru.diva-portal.org/smash/record.jsf?pid=diva2:2013183
cards_extracted:
  - energy-rsj
  - xauxag-rsj
---

# Kiss-Martins Commodity RSJ Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 explicitly directs one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete 12-page open-access published paper was read end to end,
  including the theory, daily-data construction, portfolio sorts, factor
  regressions, robustness tests, commodity list, and both appendices.
- The first extraction is the paper's monthly cross-sectional relative-signed-
  jump (RSJ) premium translated to the registered Darwinex energy carriers
  `XTIUSD.DWX` and `XNGUSD.DWX`.
- The OWNER mission dated 2026-08-06 reopens only the same locked RSJ method
  for a paired `XAUUSD.DWX` / `XAGUSD.DWX` carrier. It authorizes one durable
  G0 record, one card, a branch-only non-live build, and one paced Q02 enqueue.
  It does not authorize another characteristic, a direction change, a
  parameter sweep, or a repair of either carrier after results are observed.

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

The 2026-08-06 carrier extension, `KISS-RSJ-2025_XAU_XAG_S02`, preserves the
same source-defined estimator, direction, formation window, renewal, and
opposite-side package:

- on the first tradable XAU D1 bar of a broker month, reconstruct synchronized
  XAU and XAG simple returns from the immediately preceding complete broker
  month;
- require at least 15 returns per leg and positive total realized variance;
- compute `RSJ = (RV+ - RV-) / (RV+ + RV-)` separately for each metal;
- buy the lower-RSJ metal and short the higher-RSJ metal, with a numerical tie
  or invalid data consuming the month and remaining flat; and
- split one `RISK_FIXED=1000` package equally, use frozen per-leg ATR hard
  stops, close at the next month transition, and repair any orphan.

The source is a broad commodity-futures study, not an instrument-specific
XAU/XAG result. The governed complete-read record does not transfer an RSJ
return, significance, correlation, or sector result to this two-metal CFD
carrier. The source URL was routed again on 2026-08-06 and generic automated
retrieval was policy-deferred; the receipt is
`strategy-seeds/sources/KISS-RSJ-2025/retrieval_route_20260806.json`. No new
source content was inferred from that deferred route.

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

For `S02`, the deterministic checker scanned 4,291 EA-registry rows and 407
canonical cards. It found no exact identity and three fuzzy neighbors. Manual
mechanic review resolves them:

- `QM5_13129_energy-rsj` is the same locked source method on XTI/XNG. Its
  historical Q02 economics were negative and its Q04 walk-forward verdict was
  FAIL; that adverse evidence is disclosed and no performance is inherited.
  `S02` is a predeclared precious-metal carrier falsification, not a repair or
  rerun of the energy carrier.
- `QM5_12724_cme-xauxag-brk` is a ratio/channel breakout and
  `QM5_20202_xauxag-rev18` is an 18-month return-reversal basket. Neither
  separates positive and negative squared daily returns or calculates RSJ.
- Existing XAU/XAG ratio, OLS, quantile-envelope, calendar, momentum,
  realized-skewness, idiosyncratic-volatility, and shock strategies use
  different information objects, directions, or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback, not a monthly paired semivariance-rank package.

The one-complete-month window, normalized upside-minus-downside semivariance,
lower-RSJ-long/higher-RSJ-short direction, XAU/XAG carrier, equal package-risk
halves, and monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## R1-R4

- R1 single source: PASS. One peer-reviewed paper, DOI, and institutional
  open-access published manuscript, backed by the durable complete-read
  repository packet. The carrier extension makes no instrument-specific
  source-performance claim.
- R2 mechanical: PASS. Fixed completed-month return window, explicit RSJ
  formula and rank direction, monthly rebalance, equal risk, ATR hard stops,
  stale close, and orphan repair.
- R3 data available: PASS with translation risk. Registered XTIUSD.DWX and
  XNGUSD.DWX D1 OHLC support `S01`; registered XAUUSD.DWX and XAGUSD.DWX D1
  OHLC support `S02`. No futures chain or external runtime feed is used.
- R4 deterministic/no ML: PASS. One position per registered magic/symbol, no
  adaptive PnL fit, ML, external runtime data, grid, martingale, or pyramiding.
