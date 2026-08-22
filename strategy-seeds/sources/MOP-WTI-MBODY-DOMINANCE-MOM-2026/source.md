---
source_id: MOP-WTI-MBODY-DOMINANCE-MOM-2026
title: WTI completed-month body-dominance momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_body_dominance_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-mbody-dominance-mom
---

# WTI Completed-Month Body-Dominance Momentum Source Packet

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
`decisions/2026-08-22_wti_monthly_body_dominance_momentum_source_approval.md`,
commit `e0eb12c16`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

The paper documents positive own-return continuation across liquid futures.
It runs monthly return-predictability tests, mechanically maps an
instrument's own past-return sign to the next holding-period direction,
explicitly tests a one-month formation and one-month hold within the pooled
commodity universe, and identifies WTI as a source instrument. Those findings
support a falsifiable monthly direct-WTI trend carrier and a symmetric
long/short map.

The paper does not define aggregate completed-month OHLC, an open-to-close
real body, or body share inside a realized monthly high-low range. It does not
establish a WTI-only monthly result or test a strict one-half body threshold,
Darwinex continuous CFD, fixed-dollar ATR risk, spread ceiling, persistent
restart state, or the QM portfolio. Every such choice below is an explicit QM
hypothesis; no paper result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each broker-calendar month,
aggregate the immediately completed calendar month from completed D1 history.
Require 17 through 23 strictly ordered, unique sessions and exact adjacency to
the current decision month. Apply one uniform raw or `+1`-day energy-label
convention to the current bar and every historical bar.

Let `O0`, `C0`, `H0`, and `L0` be the chronologically first open,
chronologically final close, aggregate high, and aggregate low of the newest
completed month:

```text
body  = abs(C0 - O0)
range = H0 - L0

2 * body > range and C0 > O0  => BUY XTIUSD.DWX
2 * body > range and C0 < O0  => SELL XTIUSD.DWX
otherwise                      => FLAT
```

The open-to-close body direction is the own-price continuation state. The
strict majority body-share condition requires the completed monthly auction
to have spent more of its full range in directional displacement than in
combined rejection. The position follows that completed body direction until
the first tick of a later broker month.

Monthly OHLC aggregation, the strict majority condition, continuous-CFD
carrier, fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger,
next-month exit, and stale guard are QM choices. They are not attributed to
the source. No source alpha, Sharpe ratio, drawdown, density, CFD equivalence,
or portfolio-correlation statistic is imported.

## Exact Event Contract

All current decision-month OHLC is excluded. The prior package must be the
immediately preceding calendar month and must contain 17 through 23 unique,
strictly increasing, valid D1 sessions under one label normalization. Every
OHLC value must be positive and finite, every component high must be at least
its low and enclose its open and close, and the aggregate high must be
strictly above the aggregate low.

The completed-month open comes only from its chronologically first session;
the close comes only from its chronologically last session. Strict integer
arithmetic `2*abs(C0-O0)>H0-L0` is load-bearing. Equality at the body-share
boundary, `C0==O0`, zero range, invalid history, incomplete month, nonadjacent
month, label mismatch, or nonfinite arithmetic is flat.

One exact decision `yyyymm` attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. Attachment later than 180
elapsed minutes after the first raw D1 session open consumes the month flat.
An existing owned position or same-month entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker month closes the position; forty calendar days is a stale repair only.

There is no return-magnitude threshold beyond the body-share qualification,
parent-month comparison, close-location gate, range migration, volatility
state, volume, moving average, season, weekday, inventory, event, regression,
rank, ratio, external series, or prior-result filter. There is no retry,
target, trail, break-even move, partial close, scale-in, grid, martingale, or
pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,595 registry identities,
1,274 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and returned the expected weekly body-family matches. The durable receipt is
`artifacts/qm5_wti_mbody_dominance_mom_preallocation_dedup_20260822.json`.

Manual semantic review fixes the closest identities:

- `QM5_41092_wti-wbody-dominance-mom` aggregates one completed broker week,
  accepts three to five sessions, requires strict two-thirds body share, and
  owns the next week. This extraction aggregates one full calendar month,
  requires 17 to 23 sessions, uses a strict majority body share, and owns the
  next month. Horizon, sample, threshold, turnover, financing exposure, and
  lifecycle are jointly different; no weekly result transfers.
- `QM5_41094_xng-wbody-dominance-mom` is a weekly natural-gas carrier. This
  extraction is monthly direct WTI; no XNG or weekly result transfers.
- `QM5_20187_wti-tsmom1m` reads two month-end closes and trades every nonzero
  return sign. This extraction reads one month's first open and final close,
  aggregates its high and low, and requires a strict majority body. A weak
  body is flat, and a month-boundary gap can make the direction states differ.
- `QM5_41105_wti-mclose-location-mom` needs two completed months, derives its
  return from consecutive final closes, and confirms the newest close in the
  matching outer quartile. This extraction needs no parent close and uses the
  newest month's first open plus body-to-range share instead.
- `QM5_41102_wti-mrange-migrate-mom` compares aggregate high and low endpoints
  across two completed months and deliberately excludes opens and closes.
- `QM5_41091_wti-winside-body-mom` requires weekly parent-range containment;
  this extraction has no parent geometry and operates on one calendar month;
  and
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback beneath a slow filter. This extraction is symmetric,
  oscillator-free, direct WTI, monthly, and structural.

The exact WTI carrier, immediately completed calendar-month package,
17-to-23-session contract, first-open/final-close body, aggregate range,
strict `2*body>range` rule, own-body direction, first-new-month entry, durable
attempt, fixed risk, and next-month lifecycle are jointly load-bearing. Manual
verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_MAJORITY_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_MONTHLY_BODY_TRANSLATION_RISK`. One bounded source ID supplies
  lineage to named authors, a peer-reviewed DOI record, complete-paper
  evidence, a durable retrieval hash, and explicit WTI membership; no
  performance claim transfers.
- R2: `PASS`. Exact clock, label normalization, month adjacency, session
  count, OHLC aggregation, strict body-share comparison, side, durable
  attempt, fixed risk, stop, spread, exit, and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, comparisons,
  arithmetic, ATR, spread, quote, position, deal history, and terminal state
  only; no trained model, external feed, banned signal, grid, martingale,
  scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural monthly own-price trend carrier, not
the efficacy of this completed-month body-share gate. Expected cadence is
approximately five to nine completed positions per full post-warm-up year,
but Q02 must measure it and retire below five. Q02 also owns baseline
economics; unchanged downstream gates alone own robustness and realized
correlation.

No failure may be rescued by accepting equality, lowering the one-half
threshold, reversing the body side, changing month membership or hold, or
adding volatility, volume, season, weekday, moving-average, inventory, event,
or external-data filters.

## Safety Boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
