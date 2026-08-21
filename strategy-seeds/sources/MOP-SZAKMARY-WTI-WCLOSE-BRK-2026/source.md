---
source_id: MOP-SZAKMARY-WTI-WCLOSE-BRK-2026
title: WTI completed-week parent-range closing-breakout momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_closing_breakout_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - SZAKMARY-WTI-MCH3-2010
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  SZAKMARY-WTI-MCH3-2010: 9E082864F7F6C85E88720FC7DC24674A8BE77C68C3479D441C7709B726691727
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wclose-breakout-mom
---

# WTI Completed-Week Parent-Range Closing-Breakout Source Packet

## Approved sources of record

This bounded extraction uses one canonical child `source_id` with two governed
parents. Both parent records were read completely after the durable OWNER
source approval in
`decisions/2026-08-21_wti_weekly_closing_breakout_momentum_source_approval.md`,
commit `f0d8fe58500b81cff1b9565bb4c9d7347be20e4a`.

The first parent,
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, records Tobias J.
Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250. It records an
end-to-end read of the published 23-page paper, a retrieval receipt, and the
published-PDF SHA-256. WTI crude is an explicit member of the paper's
commodity-futures universe. The parent record SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The second parent,
`strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md`, records Andrew C.
Szakmary, Qian Shen, and Subhash C. Sharma (2010), "Trend-following trading
strategies in commodity futures: A re-examination," *Journal of Banking &
Finance* 34(2), 409-426, DOI `10.1016/j.jbankfin.2009.08.004`, plus the
complete author-uploaded predecessor manuscript that supplies the mechanical
channel rule. The parent record SHA-256 is
`9E082864F7F6C85E88720FC7DC24674A8BE77C68C3479D441C7709B726691727`.

No new online page, blocked content, inferred table value, or unrecorded
source is used.

## Source findings used

Moskowitz, Ooi, and Pedersen document positive own-return continuation across
liquid futures and mechanically map the sign of an instrument's past return
to a following holding-period direction. Their paper supports a falsifiable
direct-WTI trend carrier and symmetric long/short direction map.

Szakmary, Shen, and Sharma define a channel family in which the latest
completed commodity value is compared with prior completed extrema: above
the prior maximum is long, below the prior minimum is short, and an interior
value is flat. The governed WTI source record uses completed month ends, a
three-month prior channel, and one-month renewal.

Neither paper tests a weekly WTI final close against one parent week's full
high-low auction range. Neither establishes a two-week OHLC construction, a
one-week hold, Darwinex continuous-CFD equivalence, fixed-dollar ATR risk, a
spread ceiling, persistent restart state, or the QM portfolio. The exact
weekly mechanic below is a disclosed QM translation; no source performance
result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each normalized
Monday-anchored broker week, reconstruct exactly the two immediately
preceding completed broker weeks from completed native D1 OHLC. Apply one
uniform raw or `+1`-calendar-day energy-label convention to the current bar
and every historical bar.

The newest completed package must have the Monday anchor exactly seven
calendar days before the current decision anchor. The parent package must
have the anchor exactly seven calendar days before the newest. Each package
must contain three to five unique, strictly ordered, valid sessions. Current
decision-week OHLC never enters the signal.

Define:

```text
parent_high  = maximum high across parent-week sessions
parent_low   = minimum low across parent-week sessions
newest_close = chronologically final close of the newest completed week

newest_close > parent_high  => BUY XTIUSD.DWX
newest_close < parent_low   => SELL XTIUSD.DWX
otherwise                   => FLAT
```

Equality at either parent extreme is flat. A newest close inside the parent
range, invalid or nonpositive arithmetic, malformed OHLC, duplicate or
misordered dates, a nonadjacent anchor, or a package outside the three-to-five
session bounds is flat. Breakout distance never changes size.

The position follows the completed closing breakout until the first tick of a
later normalized broker week. The weekly horizon, one-parent extrema,
aggregate D1 high-low range, final-close endpoint, continuous-CFD carrier,
fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger, and stale
guard are QM choices. They are not attributed to either source.

## Exact event contract

Infer one energy-label offset from the raw current D1 date versus broker date:
zero for a same-day label or `+1` only when the label is exactly one calendar
day behind. Apply the selected offset uniformly to all D1 package dates while
leaving broker time unchanged. Reject any other or mixed convention.

At the first normalized bar of a new week, require attachment within 180
elapsed minutes of the raw D1 session open. Persist the normalized current
Monday-anchor attempt before history, aggregation, signal, news, spread,
quote, ATR, sizing, or order gates. A late attachment consumes the week flat.
An owned position or same-magic current-week entry deal blocks another entry.

Every OHLC value must be positive and finite; each session high must be no
lower than its open, low, and close, and each low must be no higher than its
open, high, and close. The parent aggregate high must be strictly greater
than its low. Select `newest_close` only from the chronologically final newest-
week session. The current week's open, high, low, close, and tick price are
excluded from the signal; current quotes are execution-only after the frozen
completed-week decision.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
normalized broker week closes the position; ten elapsed calendar days is a
stale repair only.

There is no newest-week own-body requirement, close-location threshold,
opposite-side range expansion, range migration, compression rank, current-
week breakout, return-magnitude threshold, moving average, volatility regime,
volume, season, weekday side, inventory, event, regression, ratio, external
series, or prior-result filter. There is no retry, target, trail, break-even
move, partial close, scale-in, grid, martingale, hedge, or pyramid.

## Non-duplicate boundary

The canonical fail-closed pre-allocation checker used the actual Company
Reference Wiki root and complete author/mechanic fields. It scanned 4,582
registry rows, 1,255 repository cards, and 45 Wiki strategy nodes, found no
exact identity, and surfaced five fuzzy family matches. Manual review fixes
the following load-bearing distinctions:

- `QM5_41091_wti-winside-body-mom` requires the newest high and low to be
  strictly inside the parent's range and follows its own body. This
  extraction requires the newest final close outside the parent range, so
  their eligible geometries cannot overlap.
- `QM5_41080_wti-wclose-location-mom` combines parent-final to newest-final
  return sign with the newest close's own-range outer-fifth location. This
  extraction ignores the parent close and newest own-range location and uses
  only the parent high/low versus newest final close.
- `QM5_41081_xng-wclose-location-mom` uses the nonidentical close-location
  mechanic on the natural-gas carrier.
- `QM5_41073_wti-woutside-settle` requires the newest weekly high above the
  parent high and low below the parent low, plus own-body direction and an
  own-range outer-quartile settlement. This extraction requires only one
  parent extreme to be cleared by the final close and has none of the other
  gates.
- `QM5_41089_wti-wrange-migrate-mom` compares both weekly range endpoints and
  never makes the newest final close decisive. This extraction ignores
  newest-range endpoint migration.
- `QM5_41061_wti-week-nr7-brk` ranks seven completed ranges, then waits for a
  completed close during the following in-progress week to escape the NR7
  range and exits Friday. This extraction has no range rank or in-progress-
  week signal and decides only at the next weekly boundary.
- `QM5_20008_wti-month-ch3` is the source-defined monthly close-only channel
  using three prior completed month-end closes. This extraction uses one
  parent weekly high-low auction and a different information clock.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  cumulative-RSI2 pullback under a slow mean, not symmetric weekly WTI price
  discovery.

The exact WTI carrier, two consecutive immediately completed
Monday-anchored OHLC packages, three-to-five-session bounds, newest final
close versus parent high/low, strict inequality and equality-flat rule,
boundary entry, durable attempt, fixed risk, and one-week hold are jointly
load-bearing. Verdict:
`NO_EXACT_DUPLICATE_PARENT_WEEK_RANGE_FINAL_CLOSE_BREAKOUT_MANUALLY_DISTINCT`.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_CHANNEL_TRANSLATION_RISK`. Two bounded source IDs
  supply named-author, peer-reviewed DOI lineages, complete-read evidence,
  explicit WTI membership, and a mechanical completed-extrema channel family.
  No source performance claim transfers.
- R2: `PASS`. Exact clock, uniform label normalization, consecutive weekly
  anchors, session counts, OHLC aggregation, final-close endpoint, strict
  parent-extreme comparison, equality-flat behavior, durable attempt, fixed
  risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, extrema, comparisons,
  ATR, spread, quote, position, deal history, and terminal state only; no
  trained model, external feed, banned signal, grid, martingale, scale-in, or
  pyramid.

## Claim and kill boundary

The sources support testing a structural own-price WTI closing-breakout
carrier, not the efficacy of this exact weekly realization. Expected cadence
is roughly ten to twenty-five completed positions per full post-warm-up year,
but Q02 must measure it and retire any full scored year below the binding
activity floor. Q02 also owns baseline economics; unchanged downstream gates
alone own robustness and realized correlation.

No failure may be rescued by accepting parent-extreme equality, substituting
the newest high or low for the final close, changing week membership, adding
current-week confirmation, changing the direction or hold, or adding a body,
close-location, outside-range, migration, compression, volatility, volume,
calendar, moving-average, inventory, event, or external-data filter.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
