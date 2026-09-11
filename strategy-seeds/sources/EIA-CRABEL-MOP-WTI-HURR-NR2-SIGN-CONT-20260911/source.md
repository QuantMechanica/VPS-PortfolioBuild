---
source_id: EIA-CRABEL-MOP-WTI-HURR-NR2-SIGN-CONT-20260911
title: WTI hurricane-season weekly contraction sign continuation
status: approved_source_complete
source_type: governed_cross_source_mechanization
approval_basis: decisions/2026-09-11_wti_hurricane_nr2_sign_continuation_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - EIA-CRABEL-MOP-WTI-HURR-NR2-SIGN-CONT-20260911_S01
parent_sources:
  - source_id: EIA-WTI-HURRICANE-2025
    role: official_hurricane_season_petroleum_supply_risk
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_own_return_continuation_lineage
---

# WTI Hurricane-Season Weekly Contraction Sign Continuation

## Source Claim

The U.S. Energy Information Administration documents Atlantic hurricane-season timing and the
exposure of Gulf Coast petroleum production, refining, and transport to storm outages. Crabel
supplies systematic volatility-contraction and range-expansion lineage. Moskowitz, Ooi, and
Pedersen document time-series momentum across futures, including crude oil.

None of those sources tests the exact rule below. This is a QM cross-source hypothesis asking
whether directional information in a completed WTI week persists after that week contracts
inside the preceding week's full range during the August-October hurricane-risk window.

## Deterministic Translation

Evaluate once at the first tradable D1 bar of every Monday-anchored broker week.

1. Continue only when the decision-week Monday anchor month is August, September, or October.
2. Aggregate the two immediately preceding consecutive completed broker weeks from D1 bars.
3. Require three through five valid, unique, ordered D1 sessions in each completed week.
4. For each week compute full range `R = high - low`. For the newest week compute the return sign
   from its chronologically earliest open and final close.
5. Require the newest range to be strictly less than the preceding range. A tie is flat.
6. BUY when the newest completed week has `close > open`; SELL when `close < open`; zero body is
   flat. No close-location, magnitude, moving-average, oscillator, breakout, or current-week gate
   exists.
7. Missing weeks, malformed or nonfinite OHLC, zero range, ineligible month, or an unavailable
   durable attempt state consumes the decision week flat. Hold no more than one position.

## Frozen Trade Management

- entry grace: 180 elapsed session minutes;
- stop loss: frozen `3.5 * ATR(20,D1)`;
- take profit: none;
- maximum spread: 1,500 points;
- normal exit: first processed tick in the next normalized broker week;
- stale repair: ten elapsed calendar days;
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- Q02 news temporal/compliance: off; Friday close: off.

## Expected Cadence And Falsification

The three-month window contains roughly thirteen decisions. A strict two-week contraction is
expected to yield about four to nine positions per full post-warm-up year. Q02 retires at zero
trades, below four completed positions in a full scored year, nonpositive governed economics, or
any execution-contract defect. No threshold may be relaxed after observing Q02.

## Provenance And Limitations

The complete bounded parent records are `strategy-seeds/sources/EIA-WTI-HURRICANE-2025/index.md`
and `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`. The former is official
government market context. The latter preserves peer-reviewed time-series-momentum and reputable
systematic range-state lineage while labeling its exact weekly rule as a QM translation.

The new hurricane-window/two-week/contraction/sign conjunction is untested. Futures-to-CFD roll,
financing, session labels, gaps, and source translation can dominate. Nothing here establishes
efficacy, causality, decorrelation, portfolio admission, or live fitness.

## Prohibited Interpretations

Do not add moving averages, oscillators, ML, adaptive thresholds, external weather or inventory
feeds, range containment, current-week price leakage, close-location gates, retry, scale-in,
grid, martingale, or parameter search.
