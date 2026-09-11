---
source_id: EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911
title: WTI hurricane-season weekly range-expansion close-location continuation
status: approved_source_complete
source_type: governed_cross_source_mechanization
approval_basis: decisions/2026-09-11_wti_hurricane_wr2_clv_continuation_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911_S01
parent_sources:
  - source_id: EIA-WTI-HURRICANE-2025
    role: official_hurricane_season_petroleum_supply_risk
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_expansion_and_own_return_continuation_lineage
---

# WTI Hurricane-Season Weekly Range-Expansion Continuation

## Source Claim

The U.S. Energy Information Administration documents Atlantic hurricane-season timing and the
exposure of Gulf Coast petroleum production, refining, and transport to storm outages. Crabel
provides systematic range-state lineage, while Moskowitz, Ooi, and Pedersen document time-series
momentum across futures, including crude oil.

None of those sources tests the exact rule below. It is a QM cross-source hypothesis asking
whether a completed WTI week that expands beyond the preceding week's range and closes in its own
upper quartile during the August-October hurricane-risk window continues into the next week.

## Deterministic Translation

Evaluate once at the first tradable D1 bar of every Monday-anchored broker week.

1. Continue only when the decision-week Monday anchor month is August, September, or October.
2. Aggregate the two immediately preceding consecutive completed broker weeks from D1 bars.
3. Require three through five valid, unique, ordered D1 sessions in each completed week.
4. For each week compute `R = high - low`; for the newest week compute
   `CLV = (close - low) / R` using its chronologically final close.
5. BUY only when the newest range is strictly greater than the prior range and `CLV > 0.75`.
6. A range tie, `CLV == 0.75`, malformed history, zero range, missing week, ineligible month, or
   nonfinite arithmetic consumes the weekly attempt flat. There is no short branch.
7. Persist the attempt before every fallible execution gate. Hold no more than one position.

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

The three-month window contains roughly thirteen decision weeks. A range-expansion and upper-
quartile conjunction is expected to yield roughly three to seven positions per full post-warm-up
year. Q02 retires at zero trades, below three completed positions in a full scored year,
nonpositive governed economics, or any execution-contract defect. No threshold may be relaxed
after observing Q02.

## Provenance And Limitations

The complete bounded parent records are `strategy-seeds/sources/EIA-WTI-HURRICANE-2025/index.md`
and `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`. The first is official
government market context; the second preserves its academic and reputable trading-research
lineage and explicitly labels its own weekly rule as a QM translation.

The new seasonal/two-week/upper-quartile conjunction is untested. Futures-to-CFD roll, financing,
session labels, gaps, and source translation can dominate. Nothing here establishes efficacy,
causality, decorrelation, portfolio admission, or live fitness.

## Prohibited Interpretations

Do not add moving averages, oscillators, ML, adaptive thresholds, external weather or inventory
feeds, current-week price leakage, shorts, retry, scale-in, grid, martingale, or parameter search.
