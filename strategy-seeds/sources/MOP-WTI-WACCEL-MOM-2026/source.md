---
source_id: MOP-WTI-WACCEL-MOM-2026
title: WTI completed-week same-sign acceleration momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-20_wti_weekly_acceleration_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-20
created_by: Research+Development
cards_extracted:
  - wti-waccel-mom
---

# WTI Completed-Week Acceleration Momentum Source Packet

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
`decisions/2026-08-20_wti_weekly_acceleration_momentum_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The paper documents positive own-return continuation and mechanically maps
the sign of an instrument's past return to the next holding-period direction.
It supports a falsifiable WTI trend hypothesis and a symmetric long/short
direction map.

The paper's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a two-week same-sign condition, or
stronger continuation after the newest absolute weekly move exceeds the
older one. It does not test a Darwinex continuous CFD, fixed-dollar ATR risk,
spread ceiling, persistent restart state, or the QM portfolio. Those are
transparent QM choices; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
reconstruct the three immediately preceding completed week-end closes. For
week-end index 1 newest through 3 oldest, define:

```text
r_new = ln(close_1 / close_2)
r_old = ln(close_2 / close_3)
```

Require finite, non-zero returns with a strict common sign and
`abs(r_new)>abs(r_old)`. Two positive accelerating weeks open BUY WTI. Two
negative accelerating weeks open SELL WTI. Close at the first later Monday
anchor or after ten calendar days.

The weekly horizon, exact endpoint reconstruction, two-return count, strict
same-sign and acceleration conditions, continuation side, CFD carrier,
fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger, next-week
exit, and stale guard are QM choices. They are not attributed to the source.
No source alpha, Sharpe ratio, drawdown, density, CFD equivalence, or
portfolio-correlation statistic is imported.

## Exact Event Contract

For positive finite completed week-end closes:

```text
r_old > 0 and r_new > 0 and abs(r_new) > abs(r_old)
    => BUY XTIUSD.DWX
r_old < 0 and r_new < 0 and abs(r_new) > abs(r_old)
    => SELL XTIUSD.DWX
otherwise
    => FLAT
```

Strict inequality is load-bearing. Equality is flat. The two weekly intervals
share only their boundary endpoint and do not overlap in return time. The
current decision-week open, high, low, or close is excluded. There is no
absolute return threshold, volatility state, volume state, standardization,
regression, order statistic, channel, range, weekday direction, external
series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,555
registry rows and 625 root cards. Existing WTI weekly systems use a fresh
adjacent-week sign handoff, one-week momentum under a volatility rank, opening
and closing subsegment agreement, range contraction and breakout, tick-volume
conditioning, or calendar/event windows. None uses exactly two adjacent
completed broker-week close returns, requires their signs to agree and the
newest absolute return to be strictly larger, immediately follows that sign,
and owns exactly the next broker week.

The three completed week ends, chronological return orientation, strict
same-sign test, strict absolute acceleration, continuation side, consumed
weekly attempt, and next-week exit are jointly load-bearing. Changing any one
creates a different identity.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_ACCELERATION_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to a named-author, peer-reviewed DOI record with a complete
  read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, return orientation, state, side,
  risk, stop, exit, attempt, and stale guard are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies all runtime inputs.
  Q02 owns history, label, density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, prices, logarithms, comparisons,
  arithmetic, ATR, spread, quote, and native trade state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural own-return trend carrier, not this
weekly acceleration gate's efficacy. Q02 must retire the card below five
completed positions per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing the number of weeks, accepting equality,
deceleration, or opposed signs, changing direction or hold, or adding a
threshold, volatility, volume, or calendar filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.

