---
source_id: MOP-WTI-MDAYBREADTH-MOM-2026
title: WTI completed-month daily-sign breadth momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_daily_sign_breadth_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-mdaybreadth-mom
---

# WTI Completed-Month Daily-Sign Breadth Momentum Source Packet

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
`decisions/2026-08-22_wti_monthly_daily_sign_breadth_momentum_source_approval.md`,
commit `12ce51468`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

The paper documents positive own-return continuation across liquid futures.
It runs monthly return-predictability tests, mechanically maps an
instrument's own past-return sign to the next holding-period direction,
explicitly tests a one-month formation and one-month hold within the pooled
commodity universe, and identifies WTI as a source instrument. Those findings
support a falsifiable monthly direct-WTI trend carrier and a symmetric
long/short map.

The paper does not count daily return signs inside the formation month or
require a daily-sign majority to agree with that month's net return. It does
not establish a WTI-only monthly result or test a Darwinex continuous CFD,
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
`C[0]...C[n-1]` be the newest completed month's chronological closes. Form one
return for every newest-month session:

```text
r[0] = C[0] / P - 1
r[i] = C[i] / C[i-1] - 1, i=1...n-1
net  = C[n-1] / P - 1

2 * count(r[i] > 0) > n && net > 0  => BUY XTIUSD.DWX
2 * count(r[i] < 0) > n && net < 0  => SELL XTIUSD.DWX
otherwise                            => FLAT
```

Zero returns remain observations in `n` and contribute to neither directional
count. The strategy follows the completed month only when both the full
endpoint return and a strict majority of its daily close-to-close path agree.
The position is held until the first tick of the next broker month.

Daily-sign breadth, the agreement condition, continuous-CFD carrier,
fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger, next-month
exit, and stale guard are QM choices. They are not attributed to the source.
No source alpha, Sharpe ratio, drawdown, density, CFD equivalence, or
portfolio-correlation statistic is imported.

## Exact Event Contract

All current decision-month prices are excluded. The newest and parent packages
must be the two immediately preceding calendar months and must each contain
17 through 23 unique, strictly increasing, valid D1 sessions under one label
normalization. Their `yyyymm` values must be consecutive across year
boundaries and adjacent to the current month.

Every close must be positive and finite. The parent anchor is only the
chronologically final parent close. The newest array contains every
chronological completed close from its month, exactly once. The first newest
return spans the parent final close to the first newest close; subsequent
returns span adjacent newest closes. No current-month close, first-open/body,
intraday high/low, skipped daily observation, or cross-month return other than
the declared first anchor is permitted.

Return signs are compared without an epsilon: a strictly higher close is up,
a strictly lower close is down, and equality is flat. `n` includes flat
observations. A BUY requires `2*up>n` and final newest close strictly above
the parent final close. A SELL requires `2*down>n` and final newest close
strictly below the parent final close. A tie, non-majority, net equality,
breadth/net disagreement, incomplete package, nonadjacent month, mixed label,
or invalid arithmetic is flat. There is no optimized majority fraction,
return-magnitude threshold, or signal-strength sizing.

One exact decision `yyyymm` attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. Attachment later than 180
elapsed minutes after the first raw D1 session open consumes the month flat.
An existing owned position or same-month entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker month closes the position; forty calendar days is a stale repair only.

There is no current-month breakout, return-magnitude threshold, breadth-margin
threshold, body-share or close-location condition, range comparison,
volatility state, volume, moving average, season, weekday, inventory, event,
regression, rank, ratio, external series, or prior-result filter. There is no
retry, target, trail, break-even move, partial close, scale-in, grid,
martingale, or pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,605 registry identities,
1,279 repository cards, and 45 Strategy-Wiki nodes. It found no exact or fuzzy
candidate match. Receipt:
`artifacts/qm5_wti_mdaybreadth_mom_preallocation_dedup_20260822.json`.

The jointly load-bearing identity is exact WTI, D1, first tradable normalized
month bar, consecutive 17-to-23-session completed calendar months, parent
final-close anchor, all newest-month close-to-close signs, strict majority,
same-sign endpoint return, one consumed monthly attempt, frozen fixed-risk
stop, and next-month hold.

It is not:

- weekly daily-sign breadth (`QM5_41084`), which uses one five-session week,
  weekly renewal, and a one-week hold rather than complete calendar months;
- twelve-month return-sign breadth (`QM5_20244`), which counts twelve monthly
  signs rather than daily signs inside one completed month;
- unconditional one-month WTI TSMOM (`QM5_20187`), which follows every
  nonzero month-end return without a daily-path confirmation;
- monthly close-location (`QM5_41105`) or body-dominance (`QM5_41106`), which
  use aggregate monthly OHLC geometry and do not count daily returns;
- monthly inside-body (`QM5_41107`) or range-expansion (`QM5_41108`), which
  condition on relations between monthly OHLC packages;
- twelve-month longest-sign-run trend (`QM5_20273`), which uses ordered runs
  of monthly returns rather than an unordered daily majority; or
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_SIGN_MAJORITY_NET_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK`: peer-reviewed JFE
  article, DOI, named authors, complete-paper review, durable retrieval hash,
  and explicit WTI membership; daily-sign breadth is disclosed as an untested
  QM state.
- R2 `PASS`: exact clock, normalization, month membership, session bounds,
  close endpoints, sign orientation, zero handling, strict majority, net
  agreement, attempt, risk, spread, stop, and lifecycle are fixed before
  results.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 plus MT5-native state supply every runtime input; Q02 owns
  label, density, cost, and continuous-CFD sufficiency.
- R4 `PASS`: closed-form timestamp/close arithmetic and framework state only;
  no ML, banned indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Frequency And Falsification

Requiring a strict daily majority to agree with the full month-end return is
expected to retain seven to ten completed positions per full post-warm-up
year. This is a hypothesis, not imported evidence. Q02 retires below the
unchanged five-trades/year/symbol floor, at zero trades or nonpositive
governed economics, or on any clock, label, month, endpoint, sign-count,
strict-majority, agreement, attempt, risk, stop, lifecycle, or determinism
defect.

No result may be rescued by treating a tie as directional, removing zero
returns from `n`, optimizing the majority fraction, dropping net agreement,
reversing direction, changing the one-month hold, loosening session bounds,
or adding volatility, volume, calendar, inventory, event, moving-average,
external-data, or prior-result filters.

## Implementation And Safety Boundary

The approved card may map the clock and locked inputs to the No-Trade module,
completed-month reconstruction and daily-sign/net agreement to Trade Entry,
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
