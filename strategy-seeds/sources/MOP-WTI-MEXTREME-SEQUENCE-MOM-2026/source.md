---
source_id: MOP-WTI-MEXTREME-SEQUENCE-MOM-2026
title: WTI completed-month extreme-sequence momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_extreme_sequence_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
closest_family_source_ids:
  - MOP-WTI-WEXTREME-SEQUENCE-MOM-2026
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mextreme-sequence-mom
---

# WTI Completed-Month Extreme-Sequence Momentum Source Packet

## Approved source of record

This bounded extraction uses the governed parent
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read completely before the
durable source approval. Its SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, a retrieval receipt, and the published-PDF
SHA-256. WTI crude oil is an explicit member of the paper's commodity-futures
universe.

The closest-family bounded packet,
`strategy-seeds/sources/MOP-WTI-WEXTREME-SEQUENCE-MOM-2026/source.md`, was
also read completely. It applies a unique-extreme chronological-order proxy
to a three-to-five-session WTI week and discloses that proxy as a QM
translation rather than a paper result.

The durable OWNER approval is
`decisions/2026-08-23_wti_monthly_extreme_sequence_momentum_source_approval.md`,
committed before this extraction at `d066ac822`. No blocked page, inferred
table value, secondary summary, or unrecorded source is used.

## Source findings used

Moskowitz, Ooi, and Pedersen document positive own-return continuation across
liquid futures and mechanically map the sign of an instrument's own past
return to the next holding-period direction. Section 3.2 and Table 2 include a
one-month formation/one-month holding commodity specification, and WTI is in
the paper's commodity universe. This supports a falsifiable direct-WTI,
symmetric, monthly trend carrier.

The paper does not define the chronological order of daily sessions carrying
a calendar month's high and low, require those aggregate extremes to occur
once, or condition direction on agreement between that order and the month's
first-open-to-last-close sign. It does not test a Darwinex continuous CFD,
fixed-dollar ATR risk, a spread ceiling, persistent restart state, or the QM
portfolio. Every such choice below is an explicit QM hypothesis. No paper
return, alpha, probability, density, risk, cost, CFD equivalence, or portfolio
correlation transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
aggregate the exact immediately completed calendar month from completed D1
OHLC. Require 17 through 23 unique, strictly chronological sessions, exact
month membership, and an adjacent older D1 bar proving the package was not
truncated. Exclude every current-month OHLC value.

For chronological completed-month sessions `i=0..n-1`, define:

```text
O = open[0]
H = max(high[i])
L = min(low[i])
C = close[n-1]
```

Require positive finite prices, valid per-session and aggregate geometry,
`H>L`, and `L<=O,C<=H`. Require exactly one session whose high equals `H` and
exactly one session whose low equals `L`. Let their unique chronological
indices be `iH` and `iL`. If either extreme repeats or `iH==iL`, the path is
ambiguous and the month remains flat.

Map extreme sequence only when the completed month's body sign agrees:

```text
iL < iH and C > O  => BUY XTIUSD.DWX
iH < iL and C < O  => SELL XTIUSD.DWX
otherwise          => FLAT
```

Close/open equality, order/body disagreement, invalid geometry, incomplete or
truncated history, repeated extremes, and same-session extremes remain flat.
Return magnitude, aggregate range, close location, and the price or session
distance between extremes never alter eligibility, side, or size.

The position follows the completed directional auction until the first tick
of a later broker-calendar month. The full calendar-month aggregation,
17-to-23-session contract, extreme-uniqueness rule, chronological sequence
test, body agreement, continuous-CFD carrier, fixed-risk budget, ATR stop,
spread cap, consumed-attempt ledger, and stale guard are QM choices. They are
not attributed to the source.

## Exact event contract

1. Derive current broker `yyyymm` from the first D1 bar time and require entry
   within 180 elapsed minutes of the raw host bar's open.
2. Require the immediately preceding completed D1 bar to belong to the prior
   calendar month. Derive that exact immediately completed month across year
   boundaries.
3. Within a fixed 45-bar buffer, accept only 17 through 23 unique valid D1
   sessions bearing that prior month. Require strict reverse-time history
   order, no current-month bar in the package, and one adjacent older bar from
   a still earlier month proving the package is complete.
4. Reverse the package into chronological order. Validate every OHLC tuple and
   aggregate geometry, count exact aggregate-high and aggregate-low
   occurrences, and reject repeated or same-session extrema.
5. Buy only for unique low-before-high plus `C>O`; sell only for unique
   high-before-low plus `C<O`; every other valid or malformed state consumes
   the month flat.
6. Persist the exact decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order gates. No retry is allowed that month.
7. Open at most one fixed-risk position. One frozen `3.5*ATR(20,D1)` hard
   stop caps the normalized loss at `RISK_FIXED=1000`; use no target and reject
   entry spread above 1,500 points.
8. Close on the first tick of a later broker month, with a forty-calendar-day
   stale repair. Invalid, duplicated, foreign-symbol, or stopless ownership
   flattens immediately.

Both news axes and Friday close are OFF. There is no parent-month comparison,
return-magnitude threshold, excursion-size threshold, body-share threshold,
wick threshold, close-location threshold, range rank, volatility regime,
volume, moving average, season, weekday side, inventory, event, regression,
ratio, external series, or prior-result filter. There is no current-month
breakout, retry, target, trail, break-even move, partial close, scale-in, grid,
martingale, or pyramid.

## Non-duplicate boundary

The canonical fail-closed pre-allocation checker used the actual Company
Reference Wiki root and scanned 4,621 registry identities, 1,290 repository
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match and
returned `CLEAN`. Evidence is
`artifacts/qm5_wti_mextreme_sequence_mom_preallocation_dedup_20260823.json`.

Manual repository-wide semantic review fixes the closest identities:

- `QM5_41098_wti-wextreme-sequence-mom` aggregates the immediately completed
  normalized Monday-anchored week, requires three to five sessions, and exits
  at the next week. This extraction uses the immediately completed 17-to-23-
  session broker-calendar month and a next-month exit; week anchors and energy
  label normalization never enter the signal.
- `QM5_41105_wti-mclose-location-mom` maps fixed monthly close quartiles. This
  extraction has no close-location threshold and uses the unique
  chronological identity of the aggregate high and low sessions.
- `QM5_41106_wti-mbody-dominance-mom` compares body magnitude with monthly
  range. This extraction uses body sign only after the path state qualifies
  and has no magnitude threshold.
- `QM5_41107_wti-minside-body-mom` and
  `QM5_41108_wti-mrange-expansion-mom` compare the completed month with a
  parent range. This extraction is invariant to every parent-month price.
- `QM5_41111_wti-mdaybreadth-mom`, `QM5_41114_wti-mhalfagree-mom`,
  `QM5_41115_wti-mthirdvote-mom`, and `QM5_41117_wti-mlatehalf-dom-mom`
  classify daily-body signs or fixed block returns. This extraction counts no
  signs or blocks and ignores intermediate opens and closes except for OHLC
  geometry.
- pure one-month WTI time-series momentum uses only the month-end return sign.
  This extraction additionally requires the completed monthly auction's
  unique extremes to appear in the same chronological direction. Equal
  endpoints can therefore produce different eligibility.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback under a slow mean, not symmetric WTI monthly structural
  continuation.

The exact WTI carrier, immediately completed broker-calendar month,
17-to-23-session contract, unique aggregate-extreme sessions, chronological
extreme order, matching close/open sign, ambiguous/disagreement-flat behavior,
boundary entry, durable attempt, fixed risk, and one-month hold are jointly
load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_EXTREME_SEQUENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1: `PASS_WITH_EXTREME_SEQUENCE_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to named authors, a peer-reviewed DOI record, a complete
  published-paper read, durable retrieval hash, explicit WTI membership, and
  a source-tested monthly direction/hold clock. The unique-extreme path state
  is explicitly untested and no performance claim transfers.
- R2: `PASS`. Exact clock, month membership, session count, chronology, OHLC
  validation, unique-extreme rule, order/body agreement, durable attempt,
  fixed risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_CALENDAR_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns history, holiday attrition, density, fills, costs, financing, and
  CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, integer index
  comparisons, ATR, spread, quote, position, deal history, and terminal state
  only; no trained model, external feed, banned signal, grid, martingale,
  scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural own-price WTI trend carrier on a
monthly clock, not the efficacy of this unique-extreme auction-path proxy.
Expected cadence is roughly six to ten completed positions per full post-
warm-up year, but Q02 must measure it and retire below five completed
positions in any full scored year. Q02 also owns baseline economics; unchanged
downstream gates alone own robustness and realized correlation.

WTI is a different commodity/energy carrier from the certified
XAU/SP500/NDX/XNG book, but that fact does not prove low correlation,
profitability, or portfolio admission. Q09 alone owns the realized portfolio
finding.

No failure may be rescued by accepting repeated or same-session extremes,
dropping body agreement, reversing the side, changing calendar-month
membership or hold, or adding magnitude, body-share, wick, close-location,
range-rank, volatility, volume, calendar, moving-average, inventory, event,
oscillator, external-data, or prior-result filters.

## Safety boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
T_Live manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
