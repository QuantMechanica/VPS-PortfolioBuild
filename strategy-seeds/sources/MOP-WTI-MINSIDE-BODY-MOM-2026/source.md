---
source_id: MOP-WTI-MINSIDE-BODY-MOM-2026
title: WTI completed-month inside-body momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_inside_body_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-minside-body-mom
---

# WTI Completed-Month Inside-Body Momentum Source Packet

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
`decisions/2026-08-22_wti_monthly_inside_body_momentum_source_approval.md`,
commit `dca99885d`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

The paper documents positive own-return continuation across liquid futures.
It runs monthly return-predictability tests, mechanically maps an
instrument's own past-return sign to the next holding-period direction,
explicitly tests a one-month formation and one-month hold within the pooled
commodity universe, and identifies WTI as a source instrument. Those findings
support a falsifiable monthly direct-WTI trend carrier and a symmetric
long/short map.

The paper does not define aggregate completed-month OHLC, strict range
containment between consecutive months, or a contained-month candle body. It
does not establish a WTI-only monthly result or test an inside-month filter,
Darwinex continuous CFD, fixed-dollar ATR risk, spread ceiling, persistent
restart state, or the QM portfolio. Every such choice below is an explicit QM
hypothesis; no paper result transfers.

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
inside = H0 < H1 && L0 > L1
body0  = C0 - O0

inside && body0 > 0  => BUY XTIUSD.DWX
inside && body0 < 0  => SELL XTIUSD.DWX
otherwise            => FLAT
```

The contained-month open-to-close direction is the own-price continuation
state. Strict parent-range containment is a completed-auction compression
condition. The position follows that completed body direction until the first
tick of a later broker month.

Monthly OHLC aggregation, strict containment, continuous-CFD carrier,
fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger, next-month
exit, and stale guard are QM choices. They are not attributed to the source.
No source alpha, Sharpe ratio, drawdown, density, CFD equivalence, or
portfolio-correlation statistic is imported.

## Exact Event Contract

All current decision-month OHLC is excluded. The newest and parent packages
must be the two immediately preceding calendar months and must each contain 17
through 23 unique, strictly increasing, valid D1 sessions under one label
normalization. Their `yyyymm` values must be consecutive across year
boundaries and adjacent to the current month.

Every OHLC value must be positive and finite, every component high/low must
enclose its open and close, and both aggregate highs must be strictly above
their lows. Each completed-month open comes only from its chronologically
first session; each close comes only from its chronologically final session.

Both containment comparisons are strict. Equal highs, equal lows,
non-contained or invalid geometry, `C0==O0`, zero range, incomplete packages,
nonadjacent months, mixed labels, or current-month leakage is flat. There is
no minimum containment width, candle-body threshold, range-ratio threshold,
or signal-strength sizing.

One exact decision `yyyymm` attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. Attachment later than 180
elapsed minutes after the first raw D1 session open consumes the month flat.
An existing owned position or same-month entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker month closes the position; forty calendar days is a stale repair only.

There is no current-month breakout, return-magnitude threshold, close-location
gate, range migration, body-share filter, volatility state, volume, moving
average, season, weekday, inventory, event, regression, rank, ratio, external
series, or prior-result filter. There is no retry, target, trail, break-even
move, partial close, scale-in, grid, martingale, or pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,596 registry identities,
1,275 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and returned only expected family fuzzy matches. The durable receipt is
`artifacts/qm5_wti_minside_body_mom_preallocation_dedup_20260822.json`.

Manual semantic review fixes the closest identities:

- `QM5_41091_wti-winside-body-mom` aggregates two completed broker weeks,
  accepts three to five sessions per package, and owns the next week. This
  extraction aggregates two full calendar months, requires 17 to 23 sessions
  each, and owns the next month. Horizon, sample, turnover, financing
  exposure, and lifecycle differ; no weekly result transfers.
- `QM5_41102_wti-mrange-migrate-mom` requires both newest high and low to
  migrate in the same direction beyond the parent. This extraction requires
  the opposite range relation, strict containment, and derives side from the
  contained month's own open and close.
- `QM5_41106_wti-mbody-dominance-mom` reads one month, has no parent
  geometry, and requires a strict majority body share. This extraction reads
  two months, requires strict containment, and has no body-share threshold.
- `QM5_20187_wti-tsmom1m` reads two month-end closes and trades every nonzero
  return sign. This extraction reads the newest month's first open and final
  close only after its entire range is strictly inside its parent's range.
- `QM5_13075_xti-inweek-brk` waits for current-week price to break a frozen
  inside-week extreme and adds multiple filters and exits. This extraction
  consumes no current-month signal OHLC and enters only at the new-month
  boundary.
- `QM5_12810_wti-month-orb` trades the new month's first-five-session opening
  range, not a completed inside-month body.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback. This extraction is symmetric, oscillator-free, direct
  WTI, monthly, and structural.

The exact WTI carrier, two consecutive completed calendar-month packages,
17-to-23-session contract, strict full containment, contained-month own-body
direction, first-new-month entry, durable attempt, fixed risk, and next-month
lifecycle are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_INSIDE_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_MONTHLY_INSIDE_BODY_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to named authors, a peer-reviewed DOI record,
  complete-paper evidence, a durable retrieval hash, and explicit WTI
  membership; no performance claim transfers.
- R2: `PASS`. Exact clock, label normalization, month adjacency, session
  counts, OHLC aggregation, strict containment, body side, durable attempt,
  fixed risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, comparisons, ATR,
  spread, quote, position, deal history, and terminal state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural monthly own-price trend carrier, not
the efficacy of this completed inside-month filter. Expected cadence is
approximately two to six completed positions per full post-warm-up year, but
Q02 must measure it and retire below two. Q02 also owns baseline economics;
unchanged downstream gates alone own robustness and realized correlation.

No failure may be rescued by accepting equality, dropping either containment
bound, changing the body direction or monthly hold, or adding volatility,
volume, season, weekday, moving-average, inventory, event, or external-data
filters.

## Safety Boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
