---
source_id: MOP-WTI-WCLOSE-LOCATION-MOM-2026
title: WTI completed-week close-location momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_completed_week_close_location_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wclose-location-mom
---

# WTI Completed-Week Close-Location Momentum Source Packet

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
`decisions/2026-08-21_wti_completed_week_close_location_momentum_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The paper documents positive own-return continuation and mechanically maps
the sign of an instrument's past return to the next holding-period direction.
It supports a falsifiable WTI trend hypothesis and a symmetric long/short
direction map.

The paper's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a completed-week range-position state, or
the `0.80` / `0.20` close-location thresholds. It does not test a Darwinex
continuous CFD, fixed-dollar ATR risk, spread ceiling, persistent restart
state, or the QM portfolio. Those are transparent QM choices; no source
result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
aggregate the immediately completed week and its consecutive parent week from
completed D1 history. Require three to five strictly ordered sessions in each
week and exact seven-calendar-day anchor adjacency.

Let `C0`, `H0`, and `L0` be the final close, high, and low of the newest
completed week, and let `C1` be the final close of its parent week:

```text
r   = ln(C0 / C1)
clv = (C0 - L0) / (H0 - L0)

r > 0 and clv > 0.80  => BUY XTIUSD.DWX
r < 0 and clv < 0.20  => SELL XTIUSD.DWX
otherwise              => FLAT
```

The strict close-to-close sign carries the source-direction mapping. The
strict close location requires the completed week to finish near the same
side of its own realized range, filtering return signs that reject before
settlement. The position follows that completed weekly direction until the
next broker week.

The weekly horizon, exact OHLC reconstruction, close-location confirmation,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap,
consumed-attempt ledger, next-week exit, and stale guard are QM choices. They
are not attributed to the source. No source alpha, Sharpe ratio, drawdown,
density, CFD equivalence, or portfolio-correlation statistic is imported.

## Exact Event Contract

All current decision-week OHLC is excluded. Strict inequalities are
load-bearing: equality at zero return or either close-location boundary is
flat. A zero or invalid completed-week range is flat. The parent and newer
weeks must use the same raw or `+1`-day label convention, have three to five
bars each, and be consecutive Monday-anchor packages. Every endpoint must be
positive and finite.

One exact Monday-anchor attempt is persisted before aggregation, signal,
news, spread, quote, ATR, sizing, or order gates. The position uses one frozen
`3.5 * ATR(20,D1)` hard stop, one `RISK_FIXED=1000` budget, no target, and a
1,500-point spread ceiling. The first tick of a later broker week closes the
position; ten calendar days is a stale repair only.

There is no return-magnitude threshold, volatility state, moving average,
regression, rank across weeks, parent high-low containment, current-week
breakout, weekday direction, external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker, including author and mechanic
fields, returned `CLEAN` across 4,567 registry rows and 625 root cards.

`QM5_41020_wti-wclose-mom` uses a Tuesday-close to Friday-close segment and a
Monday-to-Wednesday lifecycle without completed-week range aggregation.
`QM5_41073_wti-woutside-settle` requires a strict outside week, settlement
beyond its parent's high or low, and own-week open-to-close direction. This
extraction requires neither outside geometry nor a parent-range break; it
confirms the parent-close-to-new-close return sign with the newest completed
week's own high-low close location and holds the full next week.

`QM5_41065` through `QM5_41074` otherwise classify multi-week return signs,
magnitudes, transitions, dominance, or streaks without using the newest
completed week's own range position. `QM5_41061` and `QM5_12965` wait for a
current-week range break. `QM5_13049` adds magnitude and volatility-rank gates
to a rolling five-D1 return. The two completed weekly packages, newest-week
range, return sign, strict own-range close location, next-boundary entry,
consumed attempt, and same one-week direction are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_CLOSE_LOCATION_TRANSLATION_RISK`. One bounded source
  ID supplies lineage to a named-author, peer-reviewed DOI record with a
  complete read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, session counts, OHLC aggregation,
  endpoint return, close location, side, risk, stop, exit, attempt, and stale
  guard are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies all runtime inputs.
  Q02 owns history, label, density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed OHLC, comparisons,
  logarithms, arithmetic, ATR, spread, quote, and native trade state only; no
  trained model, external feed, banned signal, grid, martingale, scale-in, or
  pyramid.

## Claim And Kill Boundary

The source supports testing a structural own-return trend carrier, not this
weekly close-location gate's efficacy. Q02 must retire the card below five
completed positions per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by accepting equality, changing either close-location
boundary, removing return-sign agreement, reversing the side, changing the
hold, or adding a volatility, volume, calendar, moving-average, inventory, or
external filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.

