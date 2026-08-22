---
source_id: MOP-WTI-MHALFAGREE-MOM-2026
title: WTI completed-month two-half agreement momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_two_half_agreement_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-mhalfagree-mom
---

# WTI Completed-Month Two-Half Agreement Momentum Source Packet

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
`decisions/2026-08-22_wti_monthly_two_half_agreement_momentum_source_approval.md`,
commit `3e3264609`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

The paper documents positive own-return continuation across liquid futures.
It runs monthly return-predictability tests, mechanically maps an
instrument's own past-return sign to the next holding-period direction,
explicitly tests a one-month formation and one-month hold within the pooled
commodity universe, and identifies WTI as a source instrument. Those findings
support a falsifiable monthly direct-WTI trend carrier and a symmetric
long/short map.

The paper does not split a completed formation month into two chronological
cumulative-return legs or require those legs to share a sign. It does not
establish a WTI-only monthly result or test a Darwinex continuous CFD,
fixed-dollar ATR risk, spread ceiling, persistent restart state, or the QM
portfolio. Every such choice below is an explicit QM hypothesis; no paper
result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each broker-calendar month,
aggregate the immediately completed calendar month and its consecutive parent
from completed D1 history. Require 17 through 23 strictly ordered, unique
sessions in each package and exact adjacency to the current decision month.
Apply one uniform raw or `+1`-day energy-label convention to the current bar
and every historical bar.

Let `P` be the parent month's chronological final close and let
`C[0]...C[n-1]` be every chronological close in the newest completed month.
Set `k=floor(n/2)` and form two cumulative log-return legs:

```text
half_1 = log(C[k-1] / P)
half_2 = log(C[n-1] / C[k-1])

half_1 > 0 and half_2 > 0  => BUY XTIUSD.DWX
half_1 < 0 and half_2 < 0  => SELL XTIUSD.DWX
otherwise                  => FLAT
```

Under the locked session bound, `k` is eight through eleven. The first leg
contains the first `k` adjacent returns from `P` through `C[k-1]`; the second
contains the remaining `n-k` adjacent returns from `C[k-1]` through
`C[n-1]`. The midpoint close is an endpoint/anchor, not a duplicated return,
so the partition is exhaustive and non-overlapping. Equality, sign
disagreement, an invalid split, malformed history, or current-month leakage
consumes the month flat. Return magnitude does not affect eligibility or
sizing.

The position follows the agreeing sign and is held until the first tick of
the next broker month. The two-half agreement state, continuous-CFD carrier,
fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger, next-month
exit, and stale guard are QM choices. They are not attributed to the source.
No source alpha, Sharpe ratio, drawdown, density, CFD equivalence, or
portfolio-correlation statistic is imported.

## Exact Event Contract

All current decision-month prices are excluded. The newest and parent
packages must be the two immediately preceding calendar months and must each
contain 17 through 23 unique, strictly increasing, valid D1 sessions under
one label normalization. Their `yyyymm` values must be consecutive across
year boundaries and adjacent to the current month.

Every close must be positive and finite. The parent anchor is only the
chronologically final parent close. The newest array contains every
chronological completed close from its month, exactly once. Set
`k=floor(n/2)`, require `1 <= k < n`, and use the exact midpoint
`C[k-1]` as the first-leg endpoint and second-leg anchor. No current-month
close, open/body, intraday high/low, skipped daily observation, or alternative
split is permitted.

A BUY requires both log-return legs to be strictly positive. A SELL requires
both to be strictly negative. A zero leg, sign disagreement, invalid
arithmetic, incomplete package, nonadjacent month, mixed label, or invalid
chronology is flat. There is no epsilon, optimized split fraction,
return-magnitude threshold, or signal-strength sizing.

One exact decision `yyyymm` attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. Attachment later than 180
elapsed minutes after the raw current D1 session open consumes the month
flat. An existing owned position or same-month entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker month closes the position; forty calendar days is a stale repair only.

There is no current-month breakout, daily-sign count, fitted mean, return-
magnitude threshold, body-share or close-location condition, range
comparison, volatility state, volume, moving average, season, weekday,
inventory, event, regression, rank, ratio, external series, or prior-result
filter. There is no retry, target, trail, break-even move, partial close,
scale-in, grid, martingale, or pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,610 registry identities,
1,282 repository cards, and 45 Strategy-Wiki nodes. It found no exact or
fuzzy candidate match. Receipt:
`artifacts/qm5_wti_mhalfagree_mom_preallocation_dedup_20260822.json`.

The jointly load-bearing identity is exact WTI, D1, first tradable normalized
month bar, consecutive 17-to-23-session completed calendar months,
parent-final-close anchor, deterministic `floor(n/2)` observation split,
exhaustive non-overlapping cumulative return legs, strict same-sign agreement,
one consumed monthly attempt, frozen fixed-risk stop, and next-month hold.

It is not:

- `QM5_41021_wti-mdual-mom`, which uses full-month/final-five nested agreement
  and a five-session hold rather than two exhaustive completed-month halves
  and a one-month hold;
- `QM5_41023_wti-mends-mom`, which samples only fixed five-session opening and
  closing segments and holds five sessions rather than consuming the entire
  completed path and holding the next month;
- `QM5_41111_wti-mdaybreadth-mom`, which counts every daily return sign and
  requires a strict majority plus endpoint agreement rather than comparing
  two cumulative chronological legs;
- unconditional one-month WTI TSMOM (`QM5_20187`), which follows every
  nonzero month-end return without an internal-path confirmation;
- `QM5_41064_wti-mflip-mom`, which requires disagreement between two complete
  adjacent monthly returns rather than agreement between two legs inside one
  month;
- monthly close-location, body, inside-body, or range-expansion cards
  `QM5_41105` through `QM5_41108`, which use monthly OHLC geometry; or
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_TWO_HALF_CUMULATIVE_RETURN_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_TWO_HALF_TRANSLATION_RISK`: peer-reviewed JFE article,
  DOI, named authors, complete-paper review, durable retrieval hash, and
  explicit WTI membership; the two-half condition is disclosed as an
  untested QM state.
- R2 `PASS`: exact clock, normalization, month membership, session bounds,
  endpoints, split, return orientation, equality handling, agreement,
  attempt, risk, spread, stop, and lifecycle are fixed before results.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 plus MT5-native state supply every runtime input; Q02 owns
  label, density, cost, and continuous-CFD sufficiency.
- R4 `PASS`: closed-form timestamp/close arithmetic and framework state only;
  no ML, banned indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Frequency And Falsification

Requiring two chronological cumulative legs to share a strict sign is
expected to retain five to eight completed positions per full post-warm-up
year. This is a hypothesis, not imported evidence. Q02 retires below the
unchanged five-trades/year/symbol floor, at zero trades or nonpositive
governed economics, or on any clock, label, month, endpoint, split,
return-orientation, agreement, attempt, risk, stop, lifecycle, or determinism
defect.

No result may be rescued by moving the split, accepting equality, reversing
direction, changing the one-month hold, loosening session bounds, or adding
volatility, volume, calendar, inventory, event, moving-average, external-data,
or prior-result filters.

## Implementation And Safety Boundary

The approved card may map the clock and locked inputs to the No-Trade module,
completed-month reconstruction and two-half agreement to Trade Entry,
malformed and stale exposure repair to Trade Management, and later-month
flattening to Trade Close. The framework owns kill switch, fixed-risk sizing,
registered magic, order handling, and telemetry.

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. The source approval forbids manual
backtests, terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest
mutation, portfolio-gate changes, portfolio admission, decorrelation claims,
and correlation waivers. Strict Q01 must precede one Q02 enqueue, and the
fresh tester/host-CPU ceiling remains fail closed.
