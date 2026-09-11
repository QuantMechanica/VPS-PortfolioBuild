---
source_id: EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911
title: XNG winter weekly range-expansion close-location momentum
status: approved_source_complete
source_type: governed_cross_source_mechanization
approval_basis: decisions/2026-09-11_xng_winter_wr2_clv_momentum_source_approval.md
primary_instrument: XNGUSD.DWX
decision_timeframe: D1
strategy_ids:
  - EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911_S01
parent_sources:
  - source_id: EIA-XNG-SHOULDER-2026
    role: official_natural_gas_seasonality_context
  - source_id: MOP-TSMOM-2012
    role: peer_reviewed_own_return_continuation_lineage
  - source_id: CRABEL-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_completed_week_construction_lineage
---

# XNG Winter Weekly Range-Expansion Close-Location Momentum

## Source Claim

The U.S. Energy Information Administration documents recurring winter heating-demand peaks in
natural gas. Moskowitz, Ooi, and Pedersen document own-return time-series momentum across liquid
futures, including natural gas. Crabel supplies systematic volatility contraction/expansion
lineage, and the governed WTI packet supplies reproducible completed-week range construction.

None of the sources tests the exact rule below. This is a transparent QM cross-source hypothesis
asking whether a strictly expanding completed natural-gas week that settles in an outer quartile
continues during the next week of the November-March winter-demand window.

## Deterministic Translation

Evaluate once at the first tradable `XNGUSD.DWX` D1 bar of each normalized Monday-anchored week.

1. Continue only when the decision-week anchor month is November, December, January, February,
   or March.
2. Aggregate exactly the two immediately preceding consecutive completed broker weeks from
   normalized D1 bars. Each must contain three through five valid, unique, ordered sessions.
3. Let `R0` be the newest completed week's full range and `R1` the prior week's. Require
   `R0 > R1`; equality is flat.
4. Define newest-week `CLV=(final_close-low)/(high-low)`.
5. BUY when `CLV>0.75`; SELL when `CLV<0.25`. Equality and the interior interval are flat. The
   weekly body sign is deliberately irrelevant.
6. Persist the week attempt before calendar, history, signal, news, spread, quote, ATR, sizing,
   margin, or order gates. Never retry that week.
7. Missing/nonconsecutive weeks, malformed or nonfinite OHLC, zero range, invalid CLV, or no
   strict signal consumes the week flat. Hold at most one owned position.

## Frozen Trade Management

- entry grace: 180 elapsed minutes after the first tradable D1 bar opens;
- stop loss: frozen `3.5*ATR(20,D1)`;
- take profit: none;
- maximum spread: 1,500 points;
- normal exit: first processed tick in the next normalized broker week;
- stale repair: ten elapsed calendar days;
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- Q02 news temporal/compliance: off; Friday close: off.

## Expected Cadence And Falsification

The winter window contains roughly twenty-two decision weeks. Range expansion and outer-quartile
settlement are expected to yield approximately five to twelve completed positions per full
post-warm-up year. Q02 retires at zero trades, below five completed positions in a full scored
year, nonpositive governed economics, or any execution-contract defect. No threshold may be
relaxed after Q02.

## Provenance, Non-Duplicate Boundary, And Limitations

The bounded parents are `strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`,
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, and
`strategy-seeds/sources/CRABEL-WTI-WR4-CLOSE-MOM-2026/source.md`; each was read completely before
approval. The EIA packet is official government context, MOP is a complete-read peer-reviewed JFE
paper with DOI `10.1016/j.jfineco.2011.11.003`, and the Crabel/MOP packet records reputable range
lineage plus deterministic completed-week construction.

`QM5_41081` requires parent-close-to-new-close return-sign agreement plus outer-fifth CLV, but no
range expansion or winter calendar. `QM5_41395` follows one completed winter-week return sign, and
`QM5_41402` requires two winter-week return signs to agree. `QM5_41063` is an all-year NR7 setup
that waits for a later current-week breakout. `QM5_41434` is a WTI hurricane-window, upper-only,
long-only carrier. Certified `QM5_12567` is a long-only two-day cumulative-RSI pullback above a
slow trend. The present identity instead uses two-week relative range expansion, symmetric outer-
quartile settlement, a winter clock, and boundary entry.

Futures-to-CFD roll/basis, financing, session labels, gaps, winter-regime instability, and source
translation can dominate. Nothing here establishes efficacy, decorrelation, portfolio admission,
or live fitness.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official EIA context, complete-read
  peer-reviewed MOP lineage, and governed reputable Crabel range lineage; exact conjunction
  untested.
- R2 `PASS`: calendar, weekly packages, strict range/CLV inequalities, side, attempt, stop,
  spread, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XNGUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: timestamps, OHLC, arithmetic, ATR, quotes, positions, deals, and persistent state
  only; no trained component, banned signal, external runtime feed, grid, or martingale.

## Prohibited Interpretations

Do not add moving averages, oscillators, trained models, adaptive thresholds, body-sign filters,
current-week price leakage, external weather/storage/curve data, target, trail, scale-in, grid,
martingale, retry, optimization, or parameter search.
