---
source_id: CLARE-TFMOM-2014
title: Trend following, risk parity and momentum in commodity futures
publisher: International Review of Financial Analysis
source_type: peer_reviewed_paper
status: cards_ready
approval_basis: OWNER commodity-sleeve mission directive 2026-07-10
created: 2026-07-10
created_by: Codex
cards_extracted:
  - energy-tfmom
---

# Clare et al. Commodity Trend-Momentum Source Packet

## Source Identity And Approval

- Clare, Andrew; Seaton, James; Smith, Peter N.; and Thomas, Stephen (2014),
  "Trend following, risk parity and momentum in commodity futures",
  *International Review of Financial Analysis* 31, 1-12.
- DOI: https://doi.org/10.1016/j.irfa.2013.10.001.
- Full paper reviewed end to end: 12 pages, including method, results,
  risk-factor tests, transaction costs, conclusions, and references.
- Approval basis: the OWNER mission dated 2026-07-10 directs Codex to select,
  card, build, and enqueue one new structural commodity/energy sleeve.

## Bounded Extraction

The paper studies 28 commodity-futures return indices at monthly frequency.
Its combined rule ranks the cross-section on prior 12-month cumulative return,
keeps winners only when their own trend is positive, keeps losers only when
their trend is negative, and holds for one month. The headline combined
portfolio uses a 7-month moving-average trend signal and 60-day inverse-
volatility portfolio weights.

This packet extracts one mission-bounded carrier, `energy-tfmom`. On the first
tradable D1 bar of each broker month it ranks `XTIUSD.DWX` and `XNGUSD.DWX` on
synchronized 12-completed-month returns. It opens a paired package only when
the winner is above its own 7-completed-month mean and the loser is below its
own mean. Fixed package risk is divided by 60-D1 inverse-volatility weights.

The paper uses top and bottom groups from a 28-contract universe. A two-leg
energy carrier is therefore a constrained falsification test, not a claimed
replication. The pure trend, pure momentum, alternate moving-average, and
equal-weight results are parameter comparisons inside the same source family;
they are not additional cards for this one-edge mission.

## Source Rule And QM Translation

- Source momentum: prior 12 monthly returns, top quartile versus bottom group.
- Source trend confirmation: positive 7-month trend for winners and negative
  7-month trend for losers.
- Source risk parity: inverse realized volatility, with 60 daily observations
  in the selected combined rule.
- Source holding period: one month, rebalanced monthly.
- QM universe: XTIUSD.DWX and XNGUSD.DWX only.
- QM winner/loser: larger/smaller synchronized 12-completed-month log return.
- QM trend: latest completed month-end close above/below the arithmetic mean
  of the latest seven completed month-end closes.
- QM weight: `(1 / 60-D1 realized volatility) / sum(leg inverse volatilities)`.
- QM exit: next month transition, 35-day stale guard, ATR stop, or orphan repair.

## Evidence Boundary

The authors conclude that adding trend following to momentum lowers downside
risk without sacrificing returns. The source reports diversified portfolio
results, not a performance expectation for two Darwinex CFDs. No source
return, Sharpe ratio, drawdown, correlation, or cost estimate is imported into
the QM prior.

The source data include crude oil and natural gas, but also 26 other futures
indices, explicit contract rolling, and broad portfolio construction. The QM
carrier does not reproduce futures roll yield, collateral, term structure, or
the source cross-section. Its inverse-volatility weights reduce risk dominance;
they do not guarantee beta or dollar neutrality.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, pullback, long-only state, or
  five-day holding rule.
- Not `QM5_12733_xti-xng-xmom`: that basket always follows relative momentum;
  this card requires opposite per-leg 7-month trend confirmations and uses
  source-specified inverse-volatility risk weights.
- Not `QM5_12840_xti-xng-rspread`: no return-spread z-score or fade.
- Not `QM5_13089_xti-xng-carry`: no swap/carry rank.
- Not `QM5_13113_energy-mom-ivol`: no residual regression or idiosyncratic-
  volatility double sort.
- Not `QM5_13118_energy-skew-rank`: no third moment.
- Not `QM5_13120_energy-momrev`: no 18-month contrarian rank; this rule uses
  each leg's own 7-month trend direction.

The repository dedup helper returned `CLEAN` before EA-ID allocation for the
slug, strategy ID, author, and full mechanic.

## Runtime Guardrails

- Native XTI/XNG D1 closes, ATR, spread, broker calendar, symbol metadata, and
  framework position state only.
- No RSI, COT, inventory, futures chain, external file/API, ML, adaptive PnL
  fit, grid, martingale, or pyramiding.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`; no live artifact is made.

## Reputable-Source Criteria

- R1 PASS: peer-reviewed IRFA article with DOI and complete full text; crude
  oil and natural gas are explicit source commodities.
- R2 PASS: fixed 12-month rank, 7-month trend confirmation, 60-day inverse-
  volatility weights, monthly hold, and deterministic exits.
- R3 PASS: the carrier uses registered XTIUSD.DWX and XNGUSD.DWX D1 history.
- R4 PASS: deterministic price arithmetic only; no banned indicator, ML,
  external runtime dependency, grid, martingale, or adaptive fitting.
