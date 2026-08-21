---
source_id: MOP-WTI-WMID-OVERLAP-MOM-2026
title: WTI completed-week overlapping auction-midpoint momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_midpoint_overlap_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wmid-overlap-mom
---

# WTI Completed-Week Overlapping Auction-Midpoint Momentum Source Packet

## Approved source of record

This bounded extraction uses one canonical child `source_id` with the governed
parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read completely after
the durable source approval was committed. The parent record's SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, the retrieval receipt, and the published-PDF
SHA-256. WTI crude oil is an explicit member of the paper's commodity-futures
universe.

The OWNER source authorization is
`decisions/2026-08-21_wti_weekly_midpoint_overlap_momentum_source_approval.md`,
commit `1cd9eafe8`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source findings used

The paper documents positive own-return continuation across liquid futures
and mechanically maps the sign of an instrument's own past return to the next
holding-period direction. It supports a falsifiable direct-WTI trend carrier
and a symmetric long/short direction map.

The paper's tested formation and holding horizons are monthly. It does not
define weekly auction ranges, compare high/low midpoints, impose an overlap
state, or establish that an auction-center shift predicts the next week. It
does not test a Darwinex continuous CFD, fixed-dollar ATR risk, spread ceiling,
persistent restart state, or the QM portfolio. Every such choice below is an
explicit QM hypothesis; no paper result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
aggregate the immediately completed week and its consecutive parent week from
completed D1 highs and lows. Require three to five strictly ordered sessions
in each week and exact seven-calendar-day anchor adjacency. Apply one uniform
raw or `+1`-day energy-label convention to the current bar and every historical
bar.

For newest week zero and parent week one, define:

```text
mid0 = low0 + 0.5 * (high0 - low0)
mid1 = low1 + 0.5 * (high1 - low1)
overlap_low  = max(low0, low1)
overlap_high = min(high0, high1)
```

Require strict positive overlap, `overlap_low < overlap_high`:

```text
mid0 > mid1  => BUY XTIUSD.DWX
mid0 < mid1  => SELL XTIUSD.DWX
otherwise    => FLAT
```

The signal follows migration of the completed weekly auction center only
while the two ranges retain a common price interval. It does not use either
week's open or close, the amount of midpoint displacement, either range's
width as a rank or threshold, or a current-week breakout. Equal midpoints,
touch-only or disjoint ranges, invalid geometry, or incomplete history stay
flat.

The position follows the completed midpoint direction until the first tick of
a later broker week. The weekly horizon, high/low aggregation, overlap state,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap, consumed-
attempt ledger, next-week exit, and stale guard are QM choices. They are not
attributed to the source.

## Exact event contract

All current decision-week OHLC is excluded. The prior two packages must be the
two immediately preceding consecutive Monday anchors. Each must contain three
to five unique, strictly increasing, valid D1 sessions under the same label
normalization. Every high and low must be positive and finite, each high must
be at least its low, and each aggregate weekly high must be strictly above its
aggregate weekly low.

One exact Monday-anchor attempt is persisted before aggregation, signal, news,
spread, quote, ATR, sizing, or order gates. Attachment later than 180 elapsed
minutes after the first raw D1 bar open consumes the week flat. An existing
owned position or same-week entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker week closes the position; ten calendar days is a stale repair only.

There is no return, open, close, close-location, range-width rank, volatility,
volume, moving-average, season, weekday-side, inventory, event, regression,
ratio, external-series, or prior-result filter. There is no retry, target,
trail, break-even move, partial close, scale-in, grid, martingale, or pyramid.

## Non-duplicate boundary

The deterministic pre-allocation checker, including author and complete
mechanic fields, returned `CLEAN` across 4,579 registry rows and 625 root
cards. Manual semantic review fixes the closest identities:

- `QM5_41089_wti-wrange-migrate-mom` requires both endpoints to move in the
  same direction and accepts disjoint ranges. This extraction requires strict
  overlap and compares only the high/low midpoints; one endpoint may move
  against the other without invalidating a midpoint shift.
- `QM5_41073_wti-woutside-settle` requires a strict higher high and lower low,
  parent-extreme settlement, own-week body direction, and outer-quartile close
  location. This extraction rejects non-overlap and reads no open or close.
- `QM5_41080_wti-wclose-location-mom` follows close-to-close return sign only
  when the newest close finishes in the matching edge of its own range. This
  extraction reads no close and has no location threshold.
- `QM5_41087_wti-wr4-close-mom` ranks four completed ranges by width and
  requires body/close-location agreement. This extraction ranks no width,
  reads two weeks, and uses a strict shared-price interval.
- `QM5_41061_wti-week-nr7-brk`, `QM5_13075_xti-inside-week-brk`, and
  `QM5_12965_wti-week-orb` wait for a current-week breakout. This extraction
  enters once at the next-week boundary and never consumes current-week price
  as signal data.
- the WTI weekly return-path family classifies completed closes and return
  signs or magnitudes. This extraction classifies only completed-week highs,
  lows, overlap, and arithmetic midpoints.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

The exact WTI carrier, two consecutive completed weekly packages, three-to-
five-session contract, strict positive range overlap, strict high/low-midpoint
direction, equality/non-overlap-flat rule, boundary entry, consumed attempt,
and one-week hold are jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_AUCTION_MIDPOINT_TRANSLATION_RISK`. One bounded source
  ID supplies lineage to a named-author, peer-reviewed DOI record with a
  complete read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact clock, label normalization, week anchors, session counts,
  high/low aggregation, overlap and midpoint comparisons, side, durable
  attempt, fixed risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 state supplies every runtime input. Q02 owns label,
  history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed highs/lows, arithmetic,
  comparisons, ATR, spread, quote, position, deal history, and terminal state
  only; no trained model, external feed, banned signal, grid, martingale,
  scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural own-price trend carrier, not the
efficacy of this weekly midpoint/overlap proxy. Expected cadence is
approximately twenty to forty completed positions per full post-warm-up year,
but Q02 must measure it and retire below five. Q02 also owns baseline
economics; unchanged downstream gates alone own robustness and realized
correlation.

No failure may be rescued by accepting midpoint equality or non-overlap,
changing week membership, adding opens/closes or current-week confirmation,
reversing the side, changing the hold, or adding a displacement threshold,
range-width rank, volatility, volume, calendar, moving-average, inventory,
event, or external-data filter.

## Safety boundary

This packet supports G0 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
