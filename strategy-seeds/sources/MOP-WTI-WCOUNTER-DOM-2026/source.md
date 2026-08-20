---
source_id: MOP-WTI-WCOUNTER-DOM-2026
title: WTI completed-week countershock-dominance momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-20_wti_weekly_countershock_dominance_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-20
created_by: Research+Development
cards_extracted:
  - wti-wcounter-dom
---

# WTI Completed-Week Countershock-Dominance Source Packet

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
`decisions/2026-08-20_wti_weekly_countershock_dominance_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The paper documents positive own-return continuation and mechanically maps
the sign of an instrument's past return to the next holding-period direction.
It supports a falsifiable WTI trend hypothesis and a symmetric long/short
direction map.

The paper's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a three-return outer/counter/restoration
path, or continuation after the middle countershock strictly dominates both
outer moves combined. It does not test a Darwinex continuous CFD, fixed-dollar
ATR risk, spread ceiling, persistent restart state, or the QM portfolio. Those
are transparent QM choices; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
reconstruct the four immediately preceding completed week-end closes. For
week-end index 1 newest through 4 oldest, define chronological returns:

```text
r_oldest = ln(close_3 / close_4)
r_middle = ln(close_2 / close_3)
r_newest = ln(close_1 / close_2)
```

Require finite, non-zero returns with `sign(r_oldest)=sign(r_newest)`, the
middle return strictly opposed, and
`abs(r_middle) > abs(r_oldest) + abs(r_newest)`. A
positive/negative/positive path sells WTI. A negative/positive/negative path
buys WTI. Close at the first later Monday anchor or after ten calendar days.

Because the outer returns have one common sign and the middle return is larger
than their combined magnitude, the cumulative three-week log return has the
middle return's sign. Following the middle sign therefore follows the exact
three-week own return after a failed one-week restoration; it does not merely
reverse the latest bar.

The weekly horizon, exact endpoint reconstruction, three-return path,
combined-dominance proof, CFD carrier, fixed-risk budget, ATR stop, spread
cap, consumed-attempt ledger, next-week exit, and stale guard are QM choices.
They are not attributed to the source. No source alpha, Sharpe ratio,
drawdown, density, CFD equivalence, or portfolio-correlation statistic is
imported.

## Exact Event Contract

For positive finite completed week-end closes:

```text
r_oldest > 0 and r_middle < 0 and r_newest > 0
and abs(r_middle) > abs(r_oldest) + abs(r_newest)
    => SELL XTIUSD.DWX

r_oldest < 0 and r_middle > 0 and r_newest < 0
and abs(r_middle) > abs(r_oldest) + abs(r_newest)
    => BUY XTIUSD.DWX

otherwise
    => FLAT
```

Strict inequality is load-bearing. Equality is flat. Adjacent weekly
intervals share only boundary endpoints and do not overlap in return time.
The current decision-week open, high, low, or close is excluded. There is no
absolute return threshold, volatility state, volume state, standardization,
regression, order statistic, channel, range, weekday direction, external
series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,559
registry rows and 625 root cards. The nearest direct-WTI weekly siblings do
not share the complete identity. `QM5_41071` follows the newest restoration
sign only when that newest move dominates the middle move; this extraction
requires the opposite middle move to dominate both outer moves combined and
follows the three-week-net sign. `QM5_41065` follows every newest two-week
handoff without an older anchor. `QM5_41069` enters in the older trend before
a restoration week has completed. `QM5_41068` and `QM5_41070` require the
newest two weekly returns to share a sign. Monthly, volatility-ranked,
range-breakout, calendar, and relative-basket WTI families use different
clocks or state.

The four completed week ends, chronological return orientation, outer-sign
equality, opposed middle, strict middle-over-combined-outer dominance,
middle/net-sign direction, consumed weekly attempt, and next-week exit are
jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK`. One bounded source ID supplies
  lineage to a named-author, peer-reviewed DOI record with a complete read and
  explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, return orientation, path state,
  combined dominance, side, risk, stop, exit, attempt, and stale guard are
  fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies all runtime inputs.
  Q02 owns history, label, density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, prices, logarithms, comparisons,
  arithmetic, ATR, spread, quote, and native trade state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural own-return trend carrier, not this
weekly path-and-dominance gate's efficacy. Q02 must retire the card below two
completed positions per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing the number of weeks, accepting equality, weakening
the combined-dominance rule, removing an outer return, changing direction or
hold, or adding a threshold, volatility, volume, or calendar filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.

