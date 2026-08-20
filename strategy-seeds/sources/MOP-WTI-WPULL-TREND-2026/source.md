---
source_id: MOP-WTI-WPULL-TREND-2026
title: WTI completed-week smaller-countermove trend re-entry extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-20_wti_weekly_pullback_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-20
created_by: Research+Development
cards_extracted:
  - wti-wpull-trend
---

# WTI Completed-Week Pullback Trend Source Packet

## Approved Source Of Record

This bounded extraction uses the governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. That record documents a
complete read of Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its durable parent-file SHA-256
is recorded in the frontmatter above.

The parent paper documents own-return continuation, mechanically maps an
instrument's past return sign to the position direction, and includes NYMEX
WTI crude in its commodity universe. Its tested formation and holding
horizons are monthly. It does not test a WTI-only weekly rule, two adjacent
completed broker weeks, an opposed-sign pullback, a relative-magnitude gate,
or a Darwinex CFD package.

The durable OWNER authorization and translation boundary are recorded in
`decisions/2026-08-20_wti_weekly_pullback_trend_source_approval.md`. No new
online page, blocked content, inferred table value, or unrecorded source is
used.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
reconstruct exactly three consecutive completed broker-week-end closes. Let
index 1 be newest and index 3 oldest:

```text
r_new = ln(close_1 / close_2)
r_old = ln(close_2 / close_3)
```

Require both returns finite and non-zero, strict opposite signs, and
`abs(r_new) < abs(r_old)`. Treat the newest, smaller, opposite-sign week as a
pullback against the older direction:

```text
r_old > 0 and r_new < 0 and abs(r_new) < abs(r_old)
    => BUY XTIUSD.DWX
r_old < 0 and r_new > 0 and abs(r_new) < abs(r_old)
    => SELL XTIUSD.DWX
otherwise
    => FLAT
```

Close at the first later Monday-anchored broker-week boundary or after ten
calendar days. The weekly horizon, exact endpoint reconstruction, two-return
count, strict sign opposition, strict smaller-countermove gate, older-sign
direction, CFD carrier, fixed-risk sizing, ATR stop, spread cap, consumed
attempt, and next-week exit are transparent QM choices. No source return,
density, cost, WTI-only efficacy, CFD equivalence, or portfolio-correlation
result transfers.

## Exact Event Contract

1. The chart and only traded symbol are exact `XTIUSD.DWX`, timeframe D1,
   magic slot zero.
2. A broker week is Monday-anchored at `00:00` broker time. A completed week
   contributes its final positive D1 close before the next anchor.
3. The three selected week anchors must be consecutive. Missing or malformed
   history consumes the new week flat.
4. The current decision-week open, high, low, and close never enter either
   return.
5. Opposed signs and strict smaller newest magnitude are both load-bearing.
   Exact zero, equal magnitudes, same signs, or a larger newest move are flat.
6. Direction is always the older completed-week sign and therefore always
   opposite the newest completed-week sign. Signal magnitude never changes
   size.
7. Persist the exact current week anchor before history, news, quote, spread,
   ATR, sizing, or order gates. A failure or restart cannot retry that week.
8. One position uses one `RISK_FIXED=1000` backtest budget against a frozen
   `3.5 * ATR(20,D1)` broker hard stop, no target, and a 1,500-point entry
   spread ceiling.
9. Both news axes and Friday close are OFF. Exit at the first later week
   anchor or the ten-calendar-day stale guard. Do not trail, partially close,
   scale in, grid, martingale, pyramid, or add an external runtime dependency.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,556
EA-registry rows and 625 root cards. Manual family review separates the
nearest identities:

- `QM5_41065_wti-wflip-mom` requires opposite completed-week signs and always
  follows the newest sign; this extraction admits only a strictly smaller
  newest counterweek and trades the opposite side, in the older direction.
- `QM5_41068_wti-waccel-mom` requires two same-sign weeks and a larger newest
  magnitude; this extraction rejects every same-sign pair and requires a
  smaller newest move.
- `QM5_20239_wti-pulltrend` combines a twelve-completed-month trend ending one
  full month before a one-month counter-move; this extraction uses only two
  adjacent complete broker weeks, adds a strict relative-magnitude gate, and
  owns one week rather than one month.
- `QM5_41046_wti-wed-trend-pb` combines a twelve-month state with one standard
  Wednesday counter-move and owns the Thursday session; this extraction has
  no event weekday, slow annual state, or intraday lifecycle.
- `QM5_41051_wti-fri-weekfade` compares a completed Friday move with its
  containing week and trades a next-session fade; this extraction compares
  two disjoint full broker weeks and follows the older direction for a full
  week.
- `QM5_13049_xti-1w-mom-vol` and `QM5_21503_xti-weekly-tsmom-lowvol` use one
  completed return plus a volatility state; this extraction uses two returns
  and no volatility estimate or rank.

The exact WTI carrier, three consecutive week-end closes, two adjacent
non-overlapping returns, strict sign opposition, strict smaller newest move,
older-sign direction, consumed weekly attempt, and next-week exit are jointly
load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_PULLBACK_TRANSLATION_RISK`. Named authors, a
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, and explicit WTI membership support the trend lineage. The weekly
  smaller-countermove gate is disclosed as an untested QM entry-timing
  hypothesis.
- R2: `PASS`. Exact anchors, endpoints, return orientation, strict state,
  direction, attempt, risk, stop, spread, and lifecycle are fixed before
  testing.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history and MT5-native state supply every runtime input.
  Q02 owns history sufficiency, uniform label behavior, and CFD-basis risk.
- R4: `PASS`. Runtime uses timestamps, prices, logarithms, comparisons,
  arithmetic, ATR, spreads, quotes, positions, deal history, and framework
  state only; no trained model, banned signal, external feed, grid,
  martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing own-return continuation, not this weekly timing
rule's efficacy. Q02 must retire the card below five completed positions per
full post-warm-up year, at zero trades or nonpositive governed economics, or
on any anchor, endpoint, sign, magnitude, direction, attempt, stop, exit,
risk-mode, or determinism defect. No weak result may be rescued by accepting
same signs, equal or larger countermoves, changing direction or hold, adding a
return threshold, or adding calendar, volatility, volume, or external state.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, decorrelation claim, or correlation waiver.
