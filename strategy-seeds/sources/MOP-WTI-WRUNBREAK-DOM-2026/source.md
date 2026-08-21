---
source_id: MOP-WTI-WRUNBREAK-DOM-2026
title: WTI completed-week run-break dominance momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_run_break_dominance_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wrunbreak-dom
---

# WTI Completed-Week Run-Break Dominance Source Packet

## Approved Source Of Record

This bounded extraction uses one canonical child `source_id` with the already
governed parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read
completely before the durable source approval was written.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its durable record contains the
complete-paper review, retrieval receipt, and published-PDF SHA-256. NYMEX WTI
crude oil is an explicit member of the source commodity universe.

The durable OWNER approval is
`decisions/2026-08-21_wti_weekly_run_break_dominance_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

Moskowitz, Ooi, and Pedersen document positive own-return continuation and
mechanically map the sign of an instrument's past return to the next holding-
period direction. The paper supports a falsifiable symmetric long/short WTI
trend hypothesis.

The source's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a two-week same-sign run followed by one
opposed week, or continuation after that opposed week strictly erases the two
prior moves combined. It does not test a Darwinex continuous CFD, fixed-dollar
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

Require the two older returns to have the same strict sign, the newest return
to have the opposite strict sign, and
`abs(r_newest) > abs(r_oldest) + abs(r_middle)`. Two positive weeks followed
by a dominant negative week sell WTI. Two negative weeks followed by a
dominant positive week buy WTI. Close at the first later Monday anchor or
after ten calendar days.

Because the two older returns share a sign and the newest opposite return is
larger than their combined magnitude, the cumulative three-week log return
has the newest return's sign. Following the newest sign therefore follows the
exact three-week own return after a completed run break; it is not a fade of
the newest move.

The weekly horizon, exact endpoint reconstruction, two-week run, opposed
dominant break, combined-erasure proof, CFD carrier, fixed-risk budget, ATR
stop, spread cap, consumed-attempt ledger, next-week exit, and stale guard are
QM choices. They are not attributed to the source. No source alpha, Sharpe
ratio, drawdown, density, CFD equivalence, or portfolio-correlation statistic
is imported.

## Exact Event Contract

For positive finite completed week-end closes:

```text
r_oldest > 0 and r_middle > 0 and r_newest < 0
and abs(r_newest) > abs(r_oldest) + abs(r_middle)
    => SELL XTIUSD.DWX

r_oldest < 0 and r_middle < 0 and r_newest > 0
and abs(r_newest) > abs(r_oldest) + abs(r_middle)
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

The deterministic pre-allocation checker returned `CLEAN` across 4,569
registry rows and 625 root cards. The nearest direct-WTI weekly siblings do
not share the complete identity:

- `QM5_41065_wti-wflip-mom` follows every newest two-week sign handoff and has
  neither a second older same-sign week nor a combined-erasure proof.
- `QM5_41069_wti-wpull-trend` follows the older trend after one strictly
  smaller opposed newest week; this extraction requires the newest opposed
  week to exceed two older same-sign moves combined and follows the newest
  sign.
- `QM5_41068_wti-waccel-mom` and `QM5_41070_wti-wdecel-mom` require the newest
  two returns to share a sign; this extraction requires the newest to oppose
  both older returns.
- `QM5_41071_wti-wresume-dom` and `QM5_41072_wti-wcounter-dom` use an
  outer/opposed-middle/restored-outer topology; this extraction uses a two-
  week same-sign run followed by one opposed newest break.
- `QM5_41073_wti-woutside-settle` requires a high/low outside week and a
  settlement state; this extraction uses only four week-end closes and exact
  close-to-close log-return erasure.
- `QM5_41074_wti-wstreak3-mom` requires all three weekly returns to share one
  sign; this extraction requires the newest sign to oppose the older pair.
- `QM5_13050_xti-1w-rev-vol` fades one weekly return in a high-volatility
  regime; this extraction follows the newest and cumulative three-week sign
  without a volatility input.

The four completed week ends, chronological return orientation, strict older-
pair sign equality, opposed newest return, strict newest-over-combined-older
dominance, newest/net-sign direction, consumed weekly attempt, and next-week
exit are jointly load-bearing.

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
weekly run-break and combined-erasure gate's efficacy. Q02 must retire the
card below two completed positions per full post-warm-up year or on
nonpositive governed economics. Downstream gates alone own robustness and
correlation. No failure may be rescued by changing the number of weeks,
accepting equality, weakening the combined-erasure rule, changing direction
or hold, or adding a threshold, volatility, volume, or calendar filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
