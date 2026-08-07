---
source_id: MOP-XNG-LRTREND-2026
title: XNG monthly linear-trend quality extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-07_qm5_20262_xng_lr_trend_g0.md
parent_source_id: MOP-TSMOM-2012
created: 2026-08-07
created_by: Research+Development
cards_extracted:
  - xng-lr-trend
---

# XNG Linear-Trend Quality Source Packet

## Approved Source Of Record

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI https://doi.org/10.1016/j.jfineco.2011.11.003.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site, with retrieval time, SHA-256, page count, and complete-paper
scope in `retrieval_route_20260731.json`.

## Source Findings Used

- Section 3.1 tests own-return predictability at monthly lags one through
  sixty and reports continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from the sign of
  each instrument's own past return and renews those positions monthly.
- Appendix A includes NYMEX natural-gas futures among the paper's commodity
  universe.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling. It does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that a persistent
own-price path may contain directional information in XNG at a monthly clock.
They do not establish the candidate rule or any expected performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XNGUSD.DWX` month-end closes. Order them oldest to
newest, take natural logarithms, and fit an ordinary least-squares line against
the fixed time index `0..12`. Trade the slope direction only when the
coefficient of determination is at least `0.50`; otherwise consume the month
flat. Renew at the next broker-month boundary.

The log-price regression, fixed `R^2` threshold, continuous CFD carrier,
completed-month reconstruction, one-attempt ledger, `RISK_FIXED` sizing, ATR
hard stop, spread ceiling, and stale exit are transparent QM choices. The
paper does not specify or test them. No source return, alpha, Sharpe ratio,
drawdown, trade count, cost, threshold efficacy, CFD equivalence, neutrality,
or portfolio correlation is imported.

## Exact Statistical Contract

For thirteen completed month-end closes `P_i`, oldest to newest, define
`x_i=i`, `y_i=ln(P_i)`, `x_bar=6`, and `y_bar=average(y_i)`.

```text
Sxx  = sum((x_i - x_bar)^2)
Sxy  = sum((x_i - x_bar) * (y_i - y_bar))
Syy  = sum((y_i - y_bar)^2)
beta = Sxy / Sxx
R2   = (Sxy * Sxy) / (Sxx * Syy)
```

Require finite positive closes, thirteen distinct consecutive completed
broker months, finite arithmetic, `Sxx > 0`, `Syy > 0`,
`abs(beta) > 1e-10`, and `R2 >= 0.50`. Positive beta maps to BUY and negative
beta to SELL. The signal cannot fall back to endpoint return, moving averages,
an oscillator, a calendar direction, or a post-result threshold.

## Non-Duplicate Boundary

The deterministic pre-allocation check on 2026-08-07 scanned 4,319 EA-registry
rows and 436 intake cards. It found no exact slug or strategy-ID collision and
returned six expected lexical/source-family fuzzy neighbors. Manual review
separates the candidate from the same path-quality rule on WTI, XNG endpoint-
return TSMOM, XNG multi-horizon majority vote, XNG monthly sign breadth, the
H4 LinearRegSlope oscillator cross, and the incumbent cumulative-RSI2
pullback. A content scan found no XNG card using both thirteen completed
month-end log prices, an OLS slope, and a fixed regression-fit gate.

The price-path regression, residual-dispersion-derived `R^2`, fixed quality
threshold, flat weak-trend state, monthly consumed attempt, and renewal clock
are load-bearing. Removing the fit gate would collapse the candidate toward
the existing XNG momentum family.

## R1-R4

- R1: PASS. One canonical lineage to a named-author, peer-reviewed *Journal of
  Financial Economics* paper with DOI and a durable complete-read record.
- R2: PASS. Endpoint selection, regression orientation and formula, fixed fit
  threshold, direction, monthly attempt, stop, sizing, and exits are mechanical.
- R3: PASS. Registered `XNGUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, and deal state supply every runtime input.
- R4: PASS. Closed-form deterministic arithmetic only; no trained model,
  adaptive PnL fit, external runtime feed, grid, martingale, scale-in, or
  pyramiding.

## Safety Boundary

This source packet supports research, a V5 build, strict compile/Q01, and one
paced non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that a new sleeve is
uncorrelated before Q09 evidence.
