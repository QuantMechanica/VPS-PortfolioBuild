---
source_id: MOP-WTI-WEXTREME-SEQUENCE-MOM-2026
title: WTI completed-week extreme-sequence momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_extreme_sequence_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wextreme-sequence-mom
---

# WTI Completed-Week Extreme-Sequence Momentum Source Packet

## Approved source of record

This bounded extraction uses the governed parent
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read completely under the
durable source approval. The parent record's SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, a retrieval receipt, and the published-PDF
SHA-256. WTI crude oil is an explicit member of the paper's commodity-futures
universe.

The OWNER source authorization is
`decisions/2026-08-21_wti_weekly_extreme_sequence_momentum_source_approval.md`,
commit `e45984a099f1c3fa79083ce03167e6222f751112`. No new online page, blocked
content, inferred table value, or unrecorded source is used.

## Source findings used

The paper documents positive own-return continuation across liquid futures
and mechanically maps the sign of an instrument's own past return to the next
holding-period direction. It supports a falsifiable direct-WTI trend carrier
and symmetric long/short direction map.

The paper's tested formation and holding horizons are monthly. It does not
define the chronological order of weekly high and low sessions, require
unique extreme occurrences, or combine extreme order with weekly settlement
sign. It does not test a Darwinex continuous CFD, fixed-dollar ATR risk,
spread ceiling, persistent restart state, or the QM portfolio. Every such
choice below is an explicit QM hypothesis; no paper result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored
broker week, aggregate the immediately completed week from completed D1 OHLC.
Require three to five unique, strictly ordered sessions and exact seven-
calendar-day adjacency between the completed and current Monday anchors.
Apply one uniform raw or `+1`-day energy-label convention to the current bar
and every historical bar.

For chronological completed-week sessions `i=0..n-1`, define:

```text
O = open[0]
H = max(high[i])
L = min(low[i])
C = close[n-1]
```

Require positive finite prices, valid per-bar and aggregate geometry,
`H > L`, and `L <= O,C <= H`. Require exactly one session whose high equals
`H` and exactly one session whose low equals `L`. Let those unique
chronological indices be `iH` and `iL`. If either extreme repeats or
`iH == iL`, the sequence is ambiguous and the week remains flat.

Map extreme sequence only when final settlement agrees with the completed
auction direction:

```text
iL < iH and C > O  => BUY XTIUSD.DWX
iH < iL and C < O  => SELL XTIUSD.DWX
otherwise          => FLAT
```

Close/open equality, order/settlement disagreement, invalid geometry, an
incomplete or nonadjacent weekly package, a repeated extreme, and a same-
session high/low remain flat. Return magnitude, the distance or day count
between extremes, and the price distance from either extreme never alter
eligibility or size.

The position follows the completed directional auction until the first tick
of a later normalized broker week. The weekly aggregation, extreme-
uniqueness rule, chronological sequence test, settlement agreement, weekly
horizon, continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap,
consumed-attempt ledger, and stale guard are QM choices. They are not
attributed to the source.

## Exact event contract

All current decision-week OHLC is excluded. The completed package must have
the exact immediately preceding Monday anchor and contain three to five
unique, strictly increasing, valid D1 sessions under one label normalization.
Every OHLC value must be positive and finite; each high must be at least its
open, low, and close; each low must be at most its open, high, and close; and
the aggregate weekly high must be strictly above its low.

One exact normalized Monday-anchor attempt is persisted before aggregation,
signal, news, spread, quote, ATR, sizing, or order gates. Attachment later
than 180 elapsed minutes after the first raw D1 bar open consumes the week
flat. An existing owned position or same-week entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
normalized broker week closes the position; ten calendar days is a stale
repair only.

There is no parent-week comparison, return-magnitude threshold, excursion-
size threshold, body-share threshold, wick threshold, close-location
threshold, range rank, volatility regime, volume, moving average, season,
weekday side, inventory, event, regression, ratio, external series, or prior-
result filter. There is no current-week breakout, retry, target, trail,
break-even move, partial close, scale-in, grid, martingale, or pyramid.

## Non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,587 registry rows
and 1,266 repository cards and found no exact or fuzzy match. Its configured
optional Strategy-Wiki root was unavailable, so it returned
`INPUT_ERROR_FAIL_CLOSED` rather than a false clean result. Manual repository-
wide semantic review fixes the closest identities:

- `QM5_41095_wti-wexcursion-imbalance-mom` compares `high-open` with
  `open-low` at a strict two-to-one threshold and uses settlement agreement.
  This extraction compares no price distances and requires unique
  chronological session order for the aggregate high and low.
- `QM5_41096_wti-wexcursion-reject-rv` uses the same excursion distances with
  settlement rejection. This extraction ignores distance and rejects every
  order/settlement disagreement.
- `QM5_41092_wti-wbody-dominance-mom` uses a full-range body-share threshold.
  This extraction has no body-magnitude threshold.
- `QM5_41084_wti-wdaybreadth-mom` counts positive and negative D1 bodies.
  This extraction counts no session return signs; intermediate opens and
  closes do not enter the signal.
- `QM5_41029`, `QM5_41032`, `QM5_41033`, and their monthly relatives
  decompose close-to-open and open-to-close flows. This extraction uses no
  overnight/session decomposition.
- `QM5_41073`, `QM5_41080`, `QM5_41089`, and `QM5_41093` require a parent
  range, parent return, close location, or closing channel. This extraction
  is invariant to the parent week.
- `QM5_12965_wti-week-orb` and `QM5_13075_xti-inweek-brk` wait for a current-
  week price breakout. This extraction enters at the new-week boundary and
  uses no current-week signal price.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback under a slow mean, not direct symmetric WTI weekly
  continuation.

The exact WTI carrier, one immediately completed Monday-anchored weekly
package, three-to-five-session contract, unique aggregate-extreme sessions,
chronological extreme order, matching close/open sign, ambiguous/disagreement-
flat behavior, boundary entry, durable attempt, and one-week hold are jointly
load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_EXTREME_SEQUENCE_TRANSLATION_RISK`. One bounded
  source ID supplies lineage to a named-author, peer-reviewed DOI record with
  a complete read and explicit WTI membership; no performance claim
  transfers.
- R2: `PASS`. Exact clock, uniform label normalization, weekly anchor,
  session count, OHLC aggregation, unique-extreme rule, chronological order,
  settlement agreement, durable attempt, fixed risk, stop, spread, exit, and
  stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, integer index
  comparisons, ATR, spread, quote, position, deal history, and terminal state
  only; no trained model, external feed, banned signal, grid, martingale,
  scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural own-price trend carrier, not the
efficacy of this weekly extreme-sequence proxy. Expected cadence is roughly
fifteen to thirty completed positions per full post-warm-up year, but Q02
must measure it and retire any full scored year below the binding activity
floor. Q02 also owns baseline economics; unchanged downstream gates alone own
robustness and realized correlation.

No failure may be rescued by accepting repeated or same-session extremes,
dropping settlement agreement, changing week membership, using current-week
confirmation, reversing the side, changing the hold, or adding an excursion,
body, wick, close-location, range-rank, volatility, volume, calendar, moving-
average, inventory, event, or external-data filter.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
