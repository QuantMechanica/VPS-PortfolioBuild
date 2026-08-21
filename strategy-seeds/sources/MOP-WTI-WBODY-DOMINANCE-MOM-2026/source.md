---
source_id: MOP-WTI-WBODY-DOMINANCE-MOM-2026
title: WTI completed-week body-dominance momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_body_dominance_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wbody-dominance-mom
---

# WTI Completed-Week Body-Dominance Momentum Source Packet

## Approved source of record

This bounded extraction uses one canonical child `source_id` with the governed
parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read completely after
the durable source approval was committed. The parent record's SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, a retrieval receipt, and the published-PDF
SHA-256. WTI crude oil is an explicit member of the paper's commodity-futures
universe.

The OWNER source authorization is
`decisions/2026-08-21_wti_weekly_body_dominance_momentum_source_approval.md`,
commit `06f2ed136735590670925df9c7d243becf716c60`. No new online page,
blocked content, inferred table value, or unrecorded source is used.

## Source findings used

The paper documents positive own-return continuation across liquid futures
and mechanically maps the sign of an instrument's own past return to the next
holding-period direction. It supports a falsifiable direct-WTI trend carrier
and symmetric long/short direction map.

The paper's tested formation and holding horizons are monthly. It does not
define weekly aggregate candle geometry, test a real-body share of weekly
range, or establish a two-thirds threshold. It does not test a Darwinex
continuous CFD, fixed-dollar ATR risk, spread ceiling, persistent restart
state, or the QM portfolio. Every such choice below is an explicit QM
hypothesis; no paper result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
aggregate the immediately completed week from completed D1 OHLC. Require three
to five unique, strictly ordered sessions and exact seven-calendar-day
adjacency between the completed and current Monday anchors. Apply one uniform
raw or `+1`-day energy-label convention to the current bar and every historical
bar.

Define the completed weekly package from its chronologically first session
open, maximum high, minimum low, and chronologically final session close.
Require positive finite prices, valid per-bar and aggregate geometry, and a
strictly positive weekly range. Then define:

```text
week_range = week_high - week_low
week_body  = abs(week_close - week_open)

3 * week_body > 2 * week_range  => directional auction qualifies
```

Only after strict body dominance exists, map the completed body's sign:

```text
week_close > week_open  => BUY XTIUSD.DWX
week_close < week_open  => SELL XTIUSD.DWX
otherwise               => FLAT
```

Threshold equality is flat. Body equality, invalid geometry, an incomplete or
nonadjacent weekly package, and every body occupying two-thirds or less of the
weekly range are flat. Body magnitude beyond qualification does not change
size.

The position follows the completed directional auction until the first tick
of a later normalized broker week. The weekly aggregation, strict two-thirds
body-share gate, body endpoint choice, weekly horizon, continuous-CFD carrier,
fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger, and stale
guard are QM choices. They are not attributed to the source.

## Exact event contract

All current decision-week OHLC is excluded. The completed package must have
the exact immediately preceding Monday anchor and contain three to five
unique, strictly increasing, valid D1 sessions under one label normalization.
Every OHLC value must be positive and finite; each high must be at least the
corresponding open, low, and close; each low must be at most the open, high,
and close; and the aggregate weekly high must be strictly above its low.

One exact normalized Monday-anchor attempt is persisted before aggregation,
signal, news, spread, quote, ATR, sizing, or order gates. Attachment later
than 180 elapsed minutes after the first raw D1 bar open consumes the week
flat. An existing owned position or same-week entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
normalized broker week closes the position; ten calendar days is a stale
repair only.

There is no parent-week comparison, return-magnitude threshold, separate wick
threshold, close-location threshold, range rank, volatility regime, volume,
moving average, season, weekday side, inventory, event, regression, ratio,
external series, or prior-result filter. There is no current-week breakout,
retry, target, trail, break-even move, partial close, scale-in, grid,
martingale, or pyramid.

## Non-duplicate boundary

The canonical fail-closed pre-allocation checker used the actual Company
Reference Wiki root and complete author/mechanic fields. It returned `CLEAN`
across 4,581 registry rows, 1,254 repository cards, and 45 Wiki strategy nodes.
Manual semantic review fixes the closest identities:

- `QM5_41080_wti-wclose-location-mom` uses parent-close to newest-close return
  plus an outer-fifth close-location threshold. This extraction uses the
  newest weekly open and close and no parent close or close-location gate.
- `QM5_41087_wti-wr4-close-mom` ranks four weekly ranges and follows a narrow
  week's parent-to-newest close return. This extraction has no parent, rank,
  or compression condition.
- `QM5_41089_wti-wrange-migrate-mom` compares both high and low across two
  weeks. This extraction is invariant to every parent-week endpoint.
- `QM5_41090_wti-wmid-overlap-mom` compares high-low midpoints of two
  overlapping weeks and excludes every open and close. This extraction uses
  one week and makes its open and close load-bearing.
- `QM5_41091_wti-winside-body-mom` requires strict containment inside a
  parent week and follows any nonzero contained-week body. This extraction
  has no parent geometry and instead requires the body to occupy strictly
  more than two-thirds of its own weekly range.
- `QM5_9413_mql5-paq-marubozu` uses individual H1 bars, a 90% body, separate
  wick limits, ATR-range and EMA filters, a target, and dynamic exits across a
  different multi-symbol identity. This extraction is an exact WTI weekly
  aggregate with none of those filters and a fixed weekly lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

The exact WTI carrier, one immediately completed Monday-anchored weekly
package, three-to-five-session contract, strict real-body inequality
`3*body > 2*range`, own-body sign, threshold-equality-flat rule, boundary
entry, durable attempt, and one-week hold are jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_BODY_TRANSLATION_RISK`. One bounded source ID supplies
  lineage to a named-author, peer-reviewed DOI record with a complete read and
  explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact clock, uniform label normalization, weekly anchor, session
  count, OHLC aggregation, strict body-share inequality, side, durable
  attempt, fixed risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, arithmetic,
  comparisons, ATR, spread, quote, position, deal history, and terminal state
  only; no trained model, external feed, banned signal, grid, martingale,
  scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural own-price trend carrier, not the
efficacy of this weekly body-dominance proxy. Expected cadence is roughly ten
to twenty-five completed positions per full post-warm-up year, but Q02 must
measure it and retire any full scored year below the binding activity floor.
Q02 also owns baseline economics; unchanged downstream gates alone own
robustness and realized correlation.

No failure may be rescued by accepting threshold equality, lowering the
two-thirds boundary, changing week membership, using current-week
confirmation, reversing the side, changing the hold, or adding a wick,
close-location, range-rank, volatility, volume, calendar, moving-average,
inventory, event, or external-data filter.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
