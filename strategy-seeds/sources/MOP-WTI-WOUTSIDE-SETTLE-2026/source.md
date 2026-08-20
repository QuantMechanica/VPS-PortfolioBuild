---
source_id: MOP-WTI-WOUTSIDE-SETTLE-2026
title: WTI completed-week outside-settlement momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-20_wti_weekly_outside_settlement_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-20
created_by: Research+Development
cards_extracted:
  - wti-woutside-settle
---

# WTI Completed-Week Outside-Settlement Momentum Source Packet

## Approved Source Of Record

This bounded extraction uses one canonical child `source_id` with the already
governed parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read
completely before the durable source approval was written.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its durable record contains the
complete-paper review, retrieval receipt, and published-PDF SHA-256. WTI crude
oil is an explicit member of the source commodity universe.

The durable OWNER approval is
`decisions/2026-08-20_wti_weekly_outside_settlement_momentum_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The paper documents positive own-return continuation and mechanically maps
the sign of an instrument's past return to the next holding-period direction.
It supports a falsifiable WTI trend hypothesis and a symmetric long/short
direction map.

The paper's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a completed outside-week condition,
settlement beyond the parent range, or an outer-quartile close. It does not
test a Darwinex continuous CFD, fixed-dollar ATR risk, spread ceiling,
persistent restart state, or the QM portfolio. Those are transparent QM
choices; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
aggregate the immediately completed week and its consecutive parent week from
completed D1 OHLC. Require three to five strictly ordered sessions in each
week and exact seven-calendar-day anchor adjacency.

For the newer completed week define:

```text
outside = high_new > high_parent and low_new < low_parent
clv     = (close_new - low_new) / (high_new - low_new)

outside
and close_new > open_new
and close_new > high_parent
and clv > 0.75                                      => BUY XTIUSD.DWX

outside
and close_new < open_new
and close_new < low_parent
and clv < 0.25                                      => SELL XTIUSD.DWX

otherwise                                           => FLAT
```

The first-session open and last-session close fix the completed week's own
direction. The strict higher high and lower low establish two-sided range
expansion. Settlement beyond the parent extreme and in the matching outer
quartile removes outside weeks that reject their breakout before completion.
The position follows the completed weekly direction until the next broker
week.

The weekly horizon, exact OHLC reconstruction, range pattern, settlement and
close-location gates, continuous-CFD carrier, fixed-risk budget, ATR stop,
spread cap, consumed-attempt ledger, next-week exit, and stale guard are QM
choices. They are not attributed to the source. No source alpha, Sharpe ratio,
drawdown, density, CFD equivalence, or portfolio-correlation statistic is
imported.

## Exact Event Contract

All current decision-week OHLC is excluded. Strict inequalities are
load-bearing: equality at a parent high/low or the `0.75` / `0.25` boundary is
flat. A zero or invalid completed-week range is flat. The parent and newer
weeks must use the same raw or `+1`-day label convention, have three to five
bars each, and be consecutive Monday-anchor packages.

One exact Monday-anchor attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. The position uses one frozen
`3.5 * ATR(20,D1)` hard stop, one `RISK_FIXED=1000` budget, no target, and a
1,500-point spread ceiling. The first tick of a later broker week closes the
position; ten calendar days is a stale repair only.

There is no return-magnitude threshold, volatility state, SMA, regression,
order statistic, channel, current-week breakout, weekday direction, external
series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,560
registry rows and 625 root cards. The nearest WTI weekly siblings do not share
the complete identity.

`QM5_13095_xti-outweek-fade` uses the same broad completed outside-week family
but requires a separate current-week reversal/reclaim and trades against the
outside-week extreme with SMA/ATR context, target, and Friday flattening. This
extraction enters only at the first new-week boundary, requires the completed
week to settle outside its parent range in the matching outer quartile, follows
that direction, and holds to the next week without an SMA or target.

`QM5_41061_wti-week-nr7-brk` requires seven-week compression and waits for a
current-week break. `QM5_12965_wti-week-orb` builds and breaks the current
week's opening range. `QM5_41068` and `QM5_41070` compare adjacent weekly
close-to-close return magnitudes without high/low containment or parent-range
settlement. `QM5_41065`, `QM5_41069`, `QM5_41071`, and `QM5_41072` use
weekly return-path states without strict outside-week geometry.

The two completed OHLC packages, strict outside range, own-week sign,
parent-extreme settlement, strict close-location boundary, next-boundary
entry, consumed attempt, and same one-week direction are jointly
load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_RANGE_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to a named-author, peer-reviewed DOI record with a complete
  read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, session counts, OHLC aggregation,
  outside state, settlement, close location, side, risk, stop, exit, attempt,
  and stale guard are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies all runtime inputs.
  Q02 owns history, label, density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, comparisons,
  arithmetic, ATR, spread, quote, and native trade state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural own-return trend carrier, not this
weekly outside-settlement gate's efficacy. Q02 must retire the card below
three completed positions per full post-warm-up year or on nonpositive
governed economics. Downstream gates alone own robustness and correlation. No
failure may be rescued by accepting equality, changing the quartile boundary,
removing the parent-extreme settlement, reversing the side, changing the
hold, or adding a volatility, volume, calendar, moving-average, or external
filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.

