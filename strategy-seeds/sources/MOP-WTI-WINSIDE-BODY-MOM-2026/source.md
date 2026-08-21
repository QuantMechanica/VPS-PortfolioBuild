---
source_id: MOP-WTI-WINSIDE-BODY-MOM-2026
title: WTI completed inside-week body momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_inside_body_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-winside-body-mom
---

# WTI Completed Inside-Week Body Momentum Source Packet

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
`decisions/2026-08-21_wti_weekly_inside_body_momentum_source_approval.md`,
commit `9f47d0a0d62c3322e8ae6546f35a50ad4c1c581d`. No new online page,
blocked content, inferred table value, or unrecorded source is used.

## Source findings used

The paper documents positive own-return continuation across liquid futures
and mechanically maps the sign of an instrument's own past return to the next
holding-period direction. It supports a falsifiable direct-WTI trend carrier
and symmetric long/short direction map.

The paper's tested formation and holding horizons are monthly. It does not
define weekly auction ranges, test inside-week containment, or condition on a
contained week's open-to-close body. It does not establish that a compressed
weekly auction's own body predicts the following week. It does not test a
Darwinex continuous CFD, fixed-dollar ATR risk, spread ceiling, persistent
restart state, or the QM portfolio. Every such choice below is an explicit QM
hypothesis; no paper result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
aggregate the immediately completed week and its consecutive parent week from
completed D1 OHLC. Require three to five unique, strictly ordered sessions in
each week and exact seven-calendar-day anchor adjacency. Apply one uniform raw
or `+1`-day energy-label convention to the current bar and every historical
bar.

For newest completed week zero and parent week one, define each package from
the chronologically first session open, maximum high, minimum low, and
chronologically final session close. Require positive finite prices, valid
per-bar and aggregate geometry, and strict containment:

```text
high0 < high1 && low0 > low1
```

Only after that state exists, compute the contained week's own body:

```text
body0 = close0 - open0

body0 > 0  => BUY XTIUSD.DWX
body0 < 0  => SELL XTIUSD.DWX
otherwise  => FLAT
```

Equal endpoints are not inside. Body equality is flat. An outside, overlapping
but not contained, touch-only, disjoint, invalid, incomplete, or
nonconsecutive state is flat. The amount of containment and body magnitude do
not create thresholds or sizing changes.

The position follows the completed contained week's own direction until the
first tick of a later normalized broker week. The weekly compression gate,
body endpoint choice, weekly horizon, continuous-CFD carrier, fixed-risk
budget, ATR stop, spread cap, consumed-attempt ledger, and stale guard are QM
choices. They are not attributed to the source.

## Exact event contract

All current decision-week OHLC is excluded. The two prior packages must be the
immediately preceding consecutive Monday anchors. Each must contain three to
five unique, strictly increasing, valid D1 sessions under the same label
normalization. Every OHLC value must be positive and finite; each high must be
at least the corresponding open, low, and close; each low must be at most the
open, high, and close; and each aggregate weekly high must be strictly above
its low.

One exact normalized Monday-anchor attempt is persisted before aggregation,
signal, news, spread, quote, ATR, sizing, or order gates. Attachment later
than 180 elapsed minutes after the first raw D1 bar open consumes the week
flat. An existing owned position or same-week entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
normalized broker week closes the position; ten calendar days is a stale
repair only.

There is no parent close, inter-week return, midpoint, close-location,
containment-width, body-size, volatility-regime, volume, moving-average,
season, weekday-side, inventory, event, regression, ratio, external-series,
or prior-result filter. There is no current-week breakout, retry, target,
trail, break-even move, partial close, scale-in, grid, martingale, or pyramid.

## Non-duplicate boundary

The canonical fail-closed pre-allocation checker used the actual Company
Reference Wiki root and complete author/mechanic fields. It returned `CLEAN`
across 4,580 registry rows, 1,253 repository cards, and 45 Wiki strategy nodes.
Manual semantic review fixes the closest identities:

- `QM5_13075_xti-inweek-brk` waits for a later current-week close beyond an
  inside-week extreme and adds SMA, ATR-range, close-location, target, and
  failed-breakout rules. This extraction enters once at the boundary and never
  uses current-week signal price.
- `QM5_41061_wti-week-nr7-brk` requires the newest range to be narrowest of
  seven and waits for a current-week close breakout. This extraction compares
  only two ranges for strict containment and has no breakout.
- `QM5_41073_wti-woutside-settle` requires strict outside geometry, settlement
  beyond the parent extreme, own-body agreement, and close location. This
  extraction requires the opposite range geometry and no settlement/location
  gate.
- `QM5_41089_wti-wrange-migrate-mom` follows strict same-direction migration
  of both high and low and explicitly rejects inside geometry. This extraction
  requires the newest high to fall while its low rises.
- `QM5_41090_wti-wmid-overlap-mom` accepts any strict positive range overlap,
  compares only arithmetic high/low midpoints, and excludes all opens and
  closes. This extraction requires full containment and derives side only from
  the contained week's own open and close.
- `QM5_41080_wti-wclose-location-mom` follows parent-close to newest-close
  return only when the newest close occupies the matching outer fifth of its
  range. This extraction reads no parent close and has no close-location
  threshold.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

The exact WTI carrier, two consecutive completed weekly packages, three-to-
five-session contract, strict full containment, contained-week own-body sign,
body-equality-flat rule, boundary entry, durable attempt, and one-week hold are
jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_INSIDE_BODY_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to a named-author, peer-reviewed DOI record with a complete
  read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact clock, uniform label normalization, consecutive anchors,
  session counts, OHLC aggregation, strict containment, own-body sign, side,
  durable attempt, fixed risk, stop, spread, exit, and stale repair are
  mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, arithmetic,
  comparisons, ATR, spread, quote, position, deal history, and terminal state
  only; no trained model, external feed, banned signal, grid, martingale,
  scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural own-price trend carrier, not the
efficacy of this weekly inside-range/body proxy. Expected cadence is roughly
six to fifteen completed positions per full post-warm-up year, but Q02 must
measure it and retire any full scored year below the binding activity floor.
Q02 also owns baseline economics; unchanged downstream gates alone own
robustness and realized correlation.

No failure may be rescued by accepting equal range endpoints, replacing
strict containment with mere overlap, changing week membership, adding
current-week confirmation, reversing the side, changing the hold, or adding a
body threshold, range rank, close-location, midpoint, volatility, volume,
calendar, moving-average, inventory, event, or external-data filter.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
