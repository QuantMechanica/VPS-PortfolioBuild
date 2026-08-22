---
source_id: MOP-WTI-MRANGE-MIGRATE-MOM-2026
title: WTI completed-month auction-range migration momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_range_migration_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-mrange-migrate-mom
---

# WTI Completed-Month Auction-Range Migration Momentum Source Packet

## Approved source of record

This bounded extraction uses one canonical child `source_id` with the governed
parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read completely after
the durable source approval was committed. The parent record's SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, an author-faculty-site retrieval receipt, and the
published-PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
WTI crude is an explicit member of the paper's commodity-futures universe.

The OWNER source authorization is
`decisions/2026-08-22_wti_monthly_range_migration_momentum_source_approval.md`,
commit `e74e9ab06`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source findings used

The paper documents positive own-return continuation across liquid futures.
It runs monthly return-predictability tests, mechanically maps an instrument's
own past-return sign to the next holding-period direction, explicitly tests a
one-month formation and one-month hold within the pooled commodity universe,
and identifies WTI as a source instrument. Those findings support a
falsifiable monthly direct-WTI trend carrier and a symmetric long/short map.

The paper does not define completed-month auction ranges, aggregate daily
highs and lows into monthly packages, or establish that joint migration of
both range endpoints predicts the next month. It does not test a Darwinex
continuous CFD, fixed-dollar ATR risk, a spread ceiling, persistent restart
state, or the QM portfolio. Every such choice below is an explicit QM
hypothesis; no paper result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each broker-calendar month,
aggregate the immediately completed month and its consecutive parent month
from completed D1 high/low bars. Require 17 through 23 strictly ordered,
unique sessions in each month and exact calendar-month adjacency. Apply one
uniform raw or `+1`-day energy-label convention to the current bar and every
historical bar.

Let `H0` and `L0` be the high and low of the newest completed month, and `H1`
and `L1` the high and low of its parent:

```text
H0 > H1 and L0 > L1  => BUY XTIUSD.DWX
H0 < H1 and L0 < L1  => SELL XTIUSD.DWX
otherwise             => FLAT
```

The signal follows strict migration of both endpoints of the completed
monthly auction range. It does not use either month's open or close, the
amount of migration, the relationship between the two ranges' widths, a
current-month breakout, or an indicator. Mixed states—including an outside
month, an inside month, only one migrated endpoint, or equality at either
endpoint—stay flat.

The position follows the completed range direction until the first tick of a
later broker month. The high/low aggregation, range-state proxy,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap, consumed-
attempt ledger, next-month exit, and stale guard are QM choices. They are not
attributed to the source.

## Exact event contract

All current decision-month OHLC is excluded. The prior two packages must be
the two immediately preceding consecutive calendar months. Each must contain
17 through 23 unique, strictly increasing, valid D1 sessions under the same
label normalization. Every OHLC value must be positive and finite, each high
must be at least its low, and each aggregate monthly high must be strictly
above its aggregate monthly low.

One exact `yyyymm` attempt is persisted before aggregation, signal, news,
spread, quote, ATR, sizing, or order gates. Attachment later than 180 elapsed
minutes after the first raw D1 session open consumes the month flat. An
existing owned position or same-month entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker month closes the position; forty calendar days is a stale repair only.

There is no return, open, close, close-location, range-width, volatility,
volume, moving-average, season, weekday, inventory, event, regression, rank,
ratio, external-series, or prior-result filter. There is no retry, target,
trail, break-even move, partial close, scale-in, grid, martingale, or pyramid.

## Non-duplicate boundary

The fail-closed pre-allocation checker scanned 4,591 registry identities,
1,270 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and returned the expected fuzzy weekly-family matches. Manual semantic review
fixes the closest identities:

- `QM5_41089_wti-wrange-migrate-mom` aggregates two completed broker weeks
  and holds the next week. This extraction aggregates two complete calendar
  months, decides at most once per month, and holds the next month. The sample,
  auction horizon, turnover, financing exposure, and lifecycle differ.
- `QM5_41101_xng-wrange-migrate-mom` is a weekly natural-gas carrier. This
  extraction is monthly direct WTI; no XNG or weekly result transfers.
- `QM5_20187_wti-tsmom1m` reads two month-end closes and trades the newest
  close-to-close return sign. This extraction never reads a close and instead
  requires joint migration of aggregate highs and lows.
- `QM5_20008_wti-month-ch3` compares one month-end close with three previous
  month-end closes. This extraction has no close channel and uses two complete
  high/low packages.
- `QM5_41064_wti-mflip-mom` requires an adjacent completed-month return-sign
  change. This extraction has no return, close, or sign-flip condition.
- weekly outside-settlement, midpoint-overlap, and close-breakout cards use
  different endpoints and a different clock.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback under a slow trend filter. This extraction is symmetric,
  oscillator-free, direct WTI, and monthly.

The exact WTI carrier, two consecutive completed calendar-month high/low
packages, 17-to-23-session contract, strict same-direction migration of both
aggregate monthly extremes, mixed/equality-flat rule, month-boundary entry,
durable attempt, and one-month lifecycle are jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_MONTHLY_RANGE_STATE_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to named authors, a peer-reviewed DOI record, complete-
  paper evidence, a durable retrieval hash, and explicit WTI membership; no
  performance claim transfers.
- R2: `PASS`. Exact clock, label normalization, month adjacency, session
  counts, high/low aggregation, strict comparisons, side, durable attempt,
  fixed risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, comparisons, ATR,
  spread, quote, position, deal history, and terminal state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural monthly own-price trend carrier, not
the efficacy of this monthly auction-range proxy. Expected cadence is
approximately five to nine completed positions per full post-warm-up year,
but Q02 must measure it and retire below five. Q02 also owns baseline
economics; unchanged downstream gates alone own robustness and realized
correlation.

No failure may be rescued by accepting equality or mixed states, changing
month membership, adding opens, closes, or current-month confirmation,
reversing the side, shortening the hold, or adding return, close-location,
volatility, volume, season, weekday, moving-average, inventory, event, or
external-data filters.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
