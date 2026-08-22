---
source_id: MOP-XNG-WRANGE-MIGRATE-MOM-2026
title: XNG completed-week auction-range migration momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xng_weekly_range_migration_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xng-wrange-migrate-mom
---

# XNG Completed-Week Auction-Range Migration Momentum Source Packet

## Approved source of record

This bounded extraction uses one canonical child `source_id` with the governed
parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read completely after
the durable source approval was committed. The parent record's SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, the retrieval receipt, and the published-PDF
SHA-256. Natural-gas futures are an explicit member of the paper's commodity-
futures universe.

The OWNER source authorization is
`decisions/2026-08-22_xng_weekly_range_migration_momentum_source_approval.md`,
commit `9169ec306`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source findings used

The paper documents positive own-return continuation across liquid futures
and mechanically maps the sign of an instrument's own past return to the next
holding-period direction. It supports a falsifiable direct-XNG trend carrier
and a symmetric long/short direction map.

The paper's tested formation and holding horizons are monthly. It does not
define weekly auction ranges, compare successive weekly highs and lows, or
establish that a whole-range upward or downward migration predicts the next
week. It does not test a Darwinex continuous CFD, fixed-dollar ATR risk,
spread ceiling, persistent restart state, or the QM portfolio. Every such
choice below is an explicit QM hypothesis; no paper result transfers.

## Bounded QM mechanization

On the first tradable `XNGUSD.DWX` D1 bar of each Monday-anchored broker week,
aggregate the immediately completed week and its consecutive parent week from
completed D1 OHLC. Require three to five strictly ordered sessions in each
week and exact seven-calendar-day anchor adjacency. Apply one uniform raw or
`+1`-day energy-label convention to the current bar and every historical bar.

Let `H0` and `L0` be the high and low of the newest completed week, and `H1`
and `L1` the high and low of its parent:

```text
H0 > H1 and L0 > L1  => BUY XNGUSD.DWX
H0 < H1 and L0 < L1  => SELL XNGUSD.DWX
otherwise             => FLAT
```

The signal follows strict migration of both endpoints of the completed weekly
auction range. It does not use either week's open or close, the amount of the
migration, the relationship between the two ranges' widths, a current-week
breakout, or an indicator. Mixed states—including an outside week, an inside
week, only one migrated endpoint, or equality at either endpoint—stay flat.

The position follows the completed range direction until the first tick of a
later broker week. The weekly horizon, OHLC aggregation, range-state proxy,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap, consumed-
attempt ledger, next-week exit, and stale guard are QM choices. They are not
attributed to the source.

## Exact event contract

All current decision-week OHLC is excluded. The prior two packages must be the
two immediately preceding consecutive Monday anchors. Each must contain three
to five unique, strictly increasing, valid D1 sessions under the same label
normalization. Every OHLC value must be positive and finite, each high must be
at least its low, and each aggregate weekly high must be strictly above its
aggregate weekly low.

One exact Monday-anchor attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. Attachment later than 180
elapsed minutes after the first raw D1 bar open consumes the week flat. An
existing owned position or same-week entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker week closes the position; ten calendar days is a stale repair only.

There is no return, close-location, range-width, volatility, volume, moving-
average, season, weekday-side, inventory, event, regression, rank, ratio,
external-series, or prior-result filter. There is no retry, target, trail,
break-even move, partial close, scale-in, grid, martingale, or pyramid.

## Non-duplicate boundary

The fail-closed pre-allocation checker scanned 4,590 registry identities,
1,269 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and returned the expected fuzzy WTI carrier sibling. Manual semantic review
fixes the closest identities:

- `QM5_41089_wti-wrange-migrate-mom` implements the same structural test on
  WTI. This XNG carrier is separately authorized, carries its own history,
  basis, cost, and book-overlap risk, and inherits no WTI result.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-
  RSI2 pullback under a slow trend filter. This extraction is symmetric,
  oscillator-free, and classifies two completed weekly high-low packages.
- `QM5_41081_xng-wclose-location-mom` follows close-to-close return sign only
  when the newest close finishes in the matching edge of its own range. This
  extraction reads no close and has no close-location threshold.
- `QM5_41094_xng-wbody-dominance-mom` classifies one completed week's open-
  close body as a share of its range. This extraction reads neither open nor
  close and instead compares two complete high-low packages.
- `QM5_41063_xng-week-nr7-brk` ranks seven completed ranges and waits for a
  current-week breakout. This extraction ranks nothing, enters only at the
  next-week boundary, and excludes current-week price from the signal.
- `QM5_10596_mql5-highlow` counts a configurable run of H4 bars whose
  individual highs and lows step together and exits on an opposite H4 star;
  it is not an exact completed-week XNG auction-range/one-week package.

The exact XNG carrier, two consecutive completed weekly packages, three-to-
five-session contract, strict same-direction migration of both aggregate
weekly extremes, mixed/equality-flat rule, boundary entry, durable attempt,
and one-week lifecycle are jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_RANGE_STATE_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to named authors, a peer-reviewed DOI record, complete-
  paper evidence, a durable retrieval hash, and explicit natural-gas
  membership; no performance claim transfers.
- R2: `PASS`. Exact clock, label normalization, week anchors, session counts,
  OHLC aggregation, strict range comparisons, side, durable attempt, fixed
  risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XNGUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, comparisons, ATR,
  spread, quote, position, deal history, and terminal state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural own-price trend carrier, not the
efficacy of this weekly range-state proxy. Expected cadence is approximately
twelve to twenty-four completed positions per full post-warm-up year, but Q02
must measure it and retire below five. Q02 also owns baseline economics;
unchanged downstream gates alone own robustness and realized correlation.

No failure may be rescued by accepting equality or mixed states, changing the
week membership, adding closes or current-week confirmation, reversing the
side, changing the hold, or adding a return, close-location, volatility,
volume, calendar, moving-average, inventory, event, or external-data filter.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
