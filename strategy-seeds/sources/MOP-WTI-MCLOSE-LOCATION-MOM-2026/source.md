---
source_id: MOP-WTI-MCLOSE-LOCATION-MOM-2026
title: WTI completed-month close-location momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-mclose-location-mom
---

# WTI Completed-Month Close-Location Momentum Source Packet

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
`decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md`,
commit `896f3cd59`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

The paper documents positive own-return continuation across liquid futures.
It runs monthly return-predictability tests, mechanically maps an
instrument's own past-return sign to the next holding-period direction,
explicitly tests a one-month formation and one-month hold within the pooled
commodity universe, and identifies WTI as a source instrument. Those findings
support a falsifiable monthly direct-WTI trend carrier and a symmetric
long/short map.

The paper does not define completed-month high-low packages, a close's
location inside its realized monthly range, or outer-quartile confirmation.
It does not establish a WTI-only monthly result or test a Darwinex continuous
CFD, fixed-dollar ATR risk, spread ceiling, persistent restart state, or the
QM portfolio. Every such choice below is an explicit QM hypothesis; no paper
result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each broker-calendar month,
aggregate the immediately completed month and its consecutive parent month
from completed D1 history. Require 17 through 23 strictly ordered, unique
sessions in each month and exact calendar-month adjacency. Apply one uniform
raw or `+1`-day energy-label convention to the current bar and every
historical bar.

Let `C0`, `H0`, and `L0` be the chronologically final close, aggregate high,
and aggregate low of the newest completed month. Let `C1` be the
chronologically final close of its parent month:

```text
r   = ln(C0 / C1)
clv = (C0 - L0) / (H0 - L0)

r > 0 and clv > 0.75  => BUY XTIUSD.DWX
r < 0 and clv < 0.25  => SELL XTIUSD.DWX
otherwise              => FLAT
```

The strict close-to-close sign carries the source-direction mapping. The
strict close location requires the completed month to finish in the matching
outer quartile of its own realized auction range, filtering return signs that
rejected before settlement. The position follows that completed monthly
direction until the first tick of a later broker month.

The monthly OHLC aggregation, outer-quartile confirmation, continuous-CFD
carrier, fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger,
next-month exit, and stale guard are QM choices. They are not attributed to
the source. No source alpha, Sharpe ratio, drawdown, density, CFD equivalence,
or portfolio-correlation statistic is imported.

## Exact Event Contract

All current decision-month OHLC is excluded. The prior two packages must be
the two immediately preceding consecutive calendar months. Each must contain
17 through 23 unique, strictly increasing, valid D1 sessions under the same
label normalization. Every OHLC value must be positive and finite, every high
must be at least its low, and the newest aggregate monthly high must be
strictly above its aggregate low.

The parent and newest final closes are chosen chronologically after successful
month membership validation. Strict inequalities are load-bearing: equality
at zero return or either close-location boundary is flat. A zero or invalid
completed-month range, nonfinite logarithm, incomplete month, nonadjacent
month, label mismatch, or interior/disagreeing close is flat.

One exact `yyyymm` attempt is persisted before aggregation, signal, news,
spread, quote, ATR, sizing, or order gates. Attachment later than 180 elapsed
minutes after the first raw D1 session open consumes the month flat. An
existing owned position or same-month entry deal blocks a new entry.

The position uses one frozen `3.5 * ATR(20,D1)` hard stop, one
`RISK_FIXED=1000` budget, no take-profit, and a 1,500-point entry-spread
ceiling. Both news axes and Friday close are OFF. The first tick of a later
broker month closes the position; forty calendar days is a stale repair only.

There is no return-magnitude threshold, range-migration comparison,
volatility state, volume, moving average, season, weekday, inventory, event,
regression, rank, ratio, external series, or prior-result filter. There is no
retry, target, trail, break-even move, partial close, scale-in, grid,
martingale, or pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,594 registry identities,
1,273 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and returned expected fuzzy weekly-family matches. The durable receipt is
`artifacts/qm5_wti_mclose_location_mom_preallocation_dedup_20260822.json`.

Manual semantic review fixes the closest identities:

- `QM5_41080_wti-wclose-location-mom` aggregates two completed broker weeks,
  accepts three to five sessions per package, uses outer-fifth thresholds,
  and owns the next week. This extraction aggregates two full calendar
  months, requires 17 to 23 sessions each, uses outer-quartile thresholds,
  and owns the next month. Horizon, sample, threshold, turnover, financing
  exposure, and lifecycle are jointly different; no weekly result transfers.
- `QM5_41081_xng-wclose-location-mom` is a weekly natural-gas carrier. This
  extraction is monthly direct WTI; no XNG or weekly result transfers.
- `QM5_20187_wti-tsmom1m` reads two month-end closes and trades every nonzero
  return sign. This extraction additionally aggregates the newest month's
  high and low and requires the final close to occupy the matching outer
  quartile; interior and disagreement states are load-bearing flat cases.
- `QM5_41016_wti-mclose-mom` and `QM5_41021_wti-mdual-mom` form on a final-
  five-session segment and own only the first five sessions of the new month.
  This extraction uses a complete monthly range and owns a complete monthly
  package.
- `QM5_41102_wti-mrange-migrate-mom` compares aggregate highs and lows across
  two months and deliberately excludes closes. This extraction compares no
  range endpoints across months; it combines close-to-close sign with the
  newest month's own range position.
- weekly widest-range, outside-settlement, and inside-body cards require
  compression or parent-range geometry absent here; and
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback beneath a slow trend filter. This extraction is
  symmetric, oscillator-free, direct WTI, monthly, and structural.

The exact WTI carrier, two consecutive completed calendar-month packages,
17-to-23-session contract, parent-close-to-new-close sign, newest-month own-
range outer-quartile confirmation, first-new-month entry, durable attempt,
fixed risk, and next-month lifecycle are jointly load-bearing. Manual verdict:
`CLEAN_AFTER_EXPECTED_WEEKLY_CLOSE_LOCATION_FAMILY_FUZZY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_MONTHLY_CLOSE_LOCATION_TRANSLATION_RISK`. One bounded source
  ID supplies lineage to named authors, a peer-reviewed DOI record, complete-
  paper evidence, a durable retrieval hash, and explicit WTI membership; no
  performance claim transfers.
- R2: `PASS`. Exact clock, label normalization, month adjacency, session
  counts, OHLC aggregation, final closes, strict return and close-location
  comparisons, side, durable attempt, fixed risk, stop, spread, exit, and
  stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, comparisons,
  logarithms, arithmetic, ATR, spread, quote, position, deal history, and
  terminal state only; no trained model, external feed, banned signal, grid,
  martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural monthly own-price trend carrier, not
the efficacy of this monthly close-location gate. Expected cadence is
approximately six to ten completed positions per full post-warm-up year, but
Q02 must measure it and retire below five. Q02 also owns baseline economics;
unchanged downstream gates alone own robustness and realized correlation.

No failure may be rescued by accepting equality, changing either outer-
quartile boundary, dropping return-sign agreement, reversing the side,
changing month membership or hold, or adding volatility, volume, season,
weekday, moving-average, inventory, event, or external-data filters.

## Safety Boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading, deploy or
`T_Live` manifest, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim.
