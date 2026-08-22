---
source_id: MOP-WTI-MRANGE-EXPANSION-MOM-2026
title: WTI completed-month range-expansion momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_range_expansion_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-mrange-expansion-mom
---

# WTI Completed-Month Range-Expansion Momentum Source Packet

## Approved Source Of Record

This bounded extraction uses one canonical child `source_id` with the already
governed parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read
completely before the durable source approval was committed. The parent
record's SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, an author-faculty-site retrieval receipt, and the
published-PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
WTI crude is an explicit member of the paper's commodity-futures universe.

The OWNER source authorization is
`decisions/2026-08-22_wti_monthly_range_expansion_momentum_source_approval.md`,
commit `de681718f`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

The paper documents positive own-return continuation across liquid futures.
It runs monthly return-predictability tests, mechanically maps an
instrument's own past-return sign to the next holding-period direction,
explicitly tests a one-month formation and one-month hold within the pooled
commodity universe, and identifies WTI as a source instrument. Those findings
support a falsifiable monthly direct-WTI trend carrier and a symmetric
long/short map.

The paper does not define aggregate completed-month OHLC, compare the widths
of two consecutive monthly ranges, or use the newest month's first-open to
final-close body as direction. It does not establish a WTI-only monthly
result or test a range-expansion filter, Darwinex continuous CFD, fixed-dollar
ATR risk, spread ceiling, persistent restart state, or the QM portfolio.
Every such choice below is an explicit QM hypothesis; no paper result
transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each broker-calendar month,
aggregate the immediately completed calendar month and its consecutive parent
from completed D1 history. Require 17 through 23 strictly ordered, unique
sessions in each package and exact adjacency to the current decision month.
Apply one uniform raw or `+1`-day energy-label convention to the current bar
and every historical bar.

For newest completed month zero and parent month one, let `O`, `H`, `L`, and
`C` be chronologically first open, aggregate high, aggregate low, and
chronologically final close:

```text
range0   = H0 - L0
range1   = H1 - L1
expanded = range0 > range1
body0    = C0 - O0

expanded && body0 > 0  => BUY XTIUSD.DWX
expanded && body0 < 0  => SELL XTIUSD.DWX
otherwise              => FLAT
```

The completed month must exhibit a strictly wider auction range than its
parent. The position then follows that expanded month's own open-to-close
direction until the first tick of a later broker month. Equality is flat.

Monthly OHLC aggregation, strict range-width comparison, body-side map,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap,
consumed-attempt ledger, next-month exit, and stale guard are QM choices.
They are not attributed to the source. No source alpha, Sharpe ratio,
drawdown, density, CFD equivalence, or portfolio-correlation statistic is
imported.

## Exact Event Contract

All current decision-month OHLC is excluded. The newest and parent packages
must be the two immediately preceding calendar months and must each contain
17 through 23 unique, strictly increasing, valid D1 sessions under one label
normalization. Their `yyyymm` values must be consecutive across year
boundaries and adjacent to the current month.

Every OHLC value must be positive and finite, every component high/low must
enclose its open and close, and both aggregate highs must be strictly above
their lows. Each completed-month open comes only from its chronologically
first session; each close comes only from its chronologically final session.

Both ranges are computed from their own aggregate high and low. The newest
range must be strictly greater than the parent's. Equal or narrower range,
`C0==O0`, zero range, incomplete packages, nonadjacent months, mixed labels,
invalid arithmetic, or current-month leakage is flat. There is no minimum
expansion ratio, candle-body threshold, close-location threshold, endpoint-
migration condition, or signal-strength sizing.

One exact decision `yyyymm` attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. Attachment later than 180
elapsed minutes after the first raw D1 session open consumes the month flat.
An existing owned position or same-month entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker month closes the position; forty calendar days is a stale repair only.

There is no current-month breakout, return-magnitude threshold, range-ratio
threshold, endpoint migration, range containment, close-location gate,
body-share filter, volatility state, volume, moving average, season, weekday,
inventory, event, regression, rank, ratio, external series, or prior-result
filter. There is no retry, target, trail, break-even move, partial close,
scale-in, grid, martingale, or pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,597 registry identities,
1,276 repository cards, and 45 Strategy-Wiki nodes. It found no exact slug or
strategy-ID identity and returned only expected family fuzzy matches. Receipt:
`artifacts/qm5_wti_mrange_expansion_mom_preallocation_dedup_20260822.json`.

The jointly load-bearing identity is exact WTI, D1, first tradable normalized
month bar, two consecutive 17-to-23-session completed monthly OHLC packages,
strict `range0>range1`, newest first-open/final-close body side, equality
flat, one consumed monthly attempt, frozen fixed-risk stop, and next-month
hold.

It is not:

- monthly range migration (`QM5_41102`), which compares absolute high and low
  endpoint locations, ignores opens and closes, and can qualify while range
  width contracts;
- monthly body dominance (`QM5_41106`), which uses one month and compares its
  body with its own range rather than comparing two monthly ranges;
- monthly inside body (`QM5_41107`), whose newest range is strictly contained
  and therefore narrower, making the entry states disjoint;
- weekly range acceleration, migration, or outside-settlement variants,
  whose formation clock, turnover, and state equations differ;
- unconditional one-month WTI TSMOM (`QM5_20187`), which uses two final closes
  and does not condition on aggregate monthly range width; or
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_RANGE_EXPANSION_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_RANGE_EXPANSION_TRANSLATION_RISK`: peer-reviewed JFE
  article, DOI, named authors, complete-paper review, durable retrieval hash,
  and explicit WTI membership; monthly range expansion is disclosed as an
  untested QM state.
- R2 `PASS`: exact clock, normalization, month membership, session bounds,
  OHLC aggregation, strict inequality, direction, attempt, risk, spread,
  stop, and lifecycle are fixed before results.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 plus MT5-native state supply every runtime input; Q02 owns
  label, density, cost, and continuous-CFD sufficiency.
- R4 `PASS`: closed-form timestamp/OHLC arithmetic and framework state only;
  no ML, banned indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Frequency And Falsification

Strict range expansion should retain approximately half of monthly decisions,
so the declared expectation is five to eight completed positions per full
post-warm-up year. This is a hypothesis, not imported evidence. Q02 retires
below the unchanged five-trades/year/symbol floor, at zero trades or
nonpositive governed economics, or on any clock, label, aggregation, strict-
range, body-side, attempt, risk, stop, lifecycle, or determinism defect.

No result may be rescued by accepting equal ranges, introducing a minimum or
optimized expansion ratio, reversing the body map, changing the one-month
hold, loosening session bounds, or adding volatility, volume, calendar,
inventory, event, moving-average, external-data, or prior-result filters.

## Implementation And Safety Boundary

The approved card may map the clock and locked inputs to the No-Trade module,
monthly aggregation and strict width/body decision to Trade Entry, malformed
and stale exposure repair to Trade Management, and later-month flattening to
Trade Close. The framework owns kill switch, fixed-risk sizing, registered
magic, order handling, and telemetry.

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. The source approval forbids manual
backtests, terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest
mutation, portfolio-gate changes, portfolio admission, decorrelation claims,
and correlation waivers. Strict Q01 must precede one Q02 enqueue, and the
fresh tester/host-CPU ceiling remains fail closed.
