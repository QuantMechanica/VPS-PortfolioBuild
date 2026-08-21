---
source_id: MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026
title: WTI completed-week excursion-imbalance momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_excursion_imbalance_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wexcursion-imbalance-mom
---

# WTI Completed-Week Excursion-Imbalance Momentum Source Packet

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
`decisions/2026-08-21_wti_weekly_excursion_imbalance_momentum_source_approval.md`,
commit `0f68d9807facdfbc1baa232c7c941cdc35533f9e`. No new online page,
blocked content, inferred table value, or unrecorded source is used.

## Source findings used

The paper documents positive own-return continuation across liquid futures
and mechanically maps the sign of an instrument's own past return to the next
holding-period direction. It supports a falsifiable direct-WTI trend carrier
and symmetric long/short direction map.

The paper's tested formation and holding horizons are monthly. It does not
define weekly aggregate candle geometry, open-centred high/low excursions,
or a strict two-to-one imbalance. It does not test a Darwinex continuous CFD,
fixed-dollar ATR risk, spread ceiling, persistent restart state, or the QM
portfolio. Every such choice below is an explicit QM hypothesis; no paper
result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
aggregate the immediately completed week from completed D1 OHLC. Require
three to five unique, strictly ordered sessions and exact seven-calendar-day
adjacency between the completed and current Monday anchors. Apply one uniform
raw or `+1`-day energy-label convention to the current bar and every
historical bar.

Define the completed weekly package from its chronologically first session
open, maximum high, minimum low, and chronologically final session close.
Require positive finite prices, valid per-bar and aggregate geometry, and the
weekly open inside the aggregate range. Then define:

```text
up_excursion   = week_high - week_open
down_excursion = week_open - week_low
```

Map strict excursion imbalance only when the final settlement agrees with the
dominant direction:

```text
up_excursion > 2 * down_excursion and week_close > week_open
    => BUY XTIUSD.DWX

down_excursion > 2 * up_excursion and week_close < week_open
    => SELL XTIUSD.DWX

otherwise
    => FLAT
```

Ratio equality is flat. Close/open equality, excursion/settlement
disagreement, invalid geometry, an incomplete or nonadjacent weekly package,
and every non-strict state are flat. Magnitude beyond qualification does not
change size.

The position follows the completed directional auction until the first tick
of a later normalized broker week. The weekly aggregation, two-to-one
open-centred excursion test, settlement agreement, weekly horizon,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap,
consumed-attempt ledger, and stale guard are QM choices. They are not
attributed to the source.

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

There is no parent-week comparison, return-magnitude threshold, body-share
threshold, wick threshold, close-location threshold, range rank, volatility
regime, volume, moving average, season, weekday side, inventory, event,
regression, ratio, external series, or prior-result filter. There is no
current-week breakout, retry, target, trail, break-even move, partial close,
scale-in, grid, martingale, or pyramid.

## Non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,584 registry rows
and 1,264 repository cards. Its configured optional Strategy-Wiki root was
unavailable, so it returned `FUZZY_MATCH` rather than a false clean result.
Manual repository-wide semantic review fixes the closest identities:

- `QM5_41092_wti-wbody-dominance-mom` compares absolute weekly close/open
  body with the full range through `3*body > 2*range`. This extraction instead
  compares `high-open` with `open-low`; the close contributes only a sign
  agreement and its body magnitude cannot qualify or disqualify the setup.
- `QM5_41094_xng-wbody-dominance-mom` is both the different body-share
  mechanic and a natural-gas carrier rather than direct WTI.
- `QM5_41089_wti-wrange-migrate-mom` compares high and low across two weeks.
  This extraction uses one completed week and is invariant to its parent.
- `QM5_41080_wti-wclose-location-mom` compares parent/new closes and requires
  an outer-fifth settlement. This extraction has no parent and no range-edge
  close threshold.
- `QM5_41093_wti-wclose-breakout-mom` requires a newest close beyond a prior
  completed-week closing channel. This extraction reads no prior channel.
- `QM5_41073_wti-woutside-settle` requires an outside parent range and a close
  beyond that parent. This extraction has no parent geometry.
- generic marubozu, wick, hammer, and candlestick builds use individual
  intraday bars or add body, wick, moving-average, oscillator, target, or
  dynamic-exit contracts. None is this exact WTI weekly aggregate.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback under a slow mean, not direct symmetric WTI weekly
  continuation.

The exact WTI carrier, one immediately completed Monday-anchored weekly
package, three-to-five-session contract, strict open-centred excursion rule,
matching close/open sign, equality/disagreement-flat behavior, boundary
entry, durable attempt, and one-week hold are jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_EXCURSION_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to a named-author, peer-reviewed DOI record with a complete
  read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact clock, uniform label normalization, weekly anchor, session
  count, OHLC aggregation, strict excursion inequality, settlement agreement,
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
efficacy of this weekly excursion-imbalance proxy. Expected cadence is roughly
eight to twenty completed positions per full post-warm-up year, but Q02 must
measure it and retire any full scored year below the binding activity floor.
Q02 also owns baseline economics; unchanged downstream gates alone own
robustness and realized correlation.

No failure may be rescued by accepting ratio equality, moving the two-to-one
boundary, dropping settlement agreement, changing week membership, using
current-week confirmation, reversing the side, changing the hold, or adding a
body, wick, close-location, range-rank, volatility, volume, calendar,
moving-average, inventory, event, or external-data filter.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
