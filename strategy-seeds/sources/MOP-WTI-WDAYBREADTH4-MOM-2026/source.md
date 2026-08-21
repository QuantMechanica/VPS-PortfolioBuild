---
source_id: MOP-WTI-WDAYBREADTH4-MOM-2026
title: WTI completed-week daily-sign breadth momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_daily_sign_breadth_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wdaybreadth-mom
---

# WTI Completed-Week Daily-Sign Breadth Momentum Source Packet

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
`decisions/2026-08-21_wti_weekly_daily_sign_breadth_momentum_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

Moskowitz, Ooi, and Pedersen document positive own-return continuation and
mechanically map the sign of an instrument's past return to the next holding-
period direction. The paper supports a falsifiable symmetric long/short WTI
trend hypothesis.

The source's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a four-of-five daily-sign breadth effect,
or added efficacy from requiring the completed week's net return to agree.
It does not test a Darwinex continuous CFD, fixed-dollar ATR risk, spread
ceiling, persistent restart state, or the QM portfolio. Those are transparent
QM choices; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
reconstruct the final close of the parent completed week and all five
chronological closes in the immediately completed week. Let `C0` be the
parent final close and `C1` through `C5` be the newest completed week's five
session closes in chronological order. Define:

```text
r1 = ln(C1 / C0)
r2 = ln(C2 / C1)
r3 = ln(C3 / C2)
r4 = ln(C4 / C3)
r5 = ln(C5 / C4)
weekly_net = ln(C5 / C0)
```

Count each `ri > 0` as positive and each `ri < 0` as negative; exact zero
counts toward neither side. Buy when at least four returns are positive and
`weekly_net > 0`. Sell when at least four are negative and `weekly_net < 0`.
Otherwise consume the week flat. Close at the first later Monday anchor or
after ten calendar days.

The four-of-five condition measures directional participation across the
formation week's adjacent daily intervals. Weekly-net agreement prevents the
minority interval from reversing the total formation direction. The weekly
horizon, exact five-session requirement, breadth threshold, net conjunction,
CFD carrier, fixed-risk budget, ATR stop, spread cap, consumed-attempt ledger,
next-week exit, and stale guard are QM choices. They are not attributed to the
source. No source alpha, Sharpe ratio, drawdown, density, CFD equivalence, or
portfolio-correlation statistic is imported.

## Exact Event Contract

For positive finite chronological closes `C0` through `C5`:

```text
positive_count >= 4 and weekly_net > 0  => BUY XTIUSD.DWX
negative_count >= 4 and weekly_net < 0  => SELL XTIUSD.DWX
otherwise                               => FLAT
```

Exactly five newest-week D1 sessions are mandatory. Strict comparisons are
load-bearing. Equality and exact-zero component returns do not qualify.
Adjacent intervals share boundary closes but do not overlap in return time.
The current decision-week open, high, low, or close is excluded. There is no
absolute-return threshold, volatility state, volume state, standardization,
regression, order statistic, channel, range-location rule, weekday direction,
external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,571
registry rows and 625 root cards. The nearest direct-WTI relatives do not
share the complete identity:

- `QM5_41080_wti-wclose-location-mom` uses one weekly return sign plus the
  newest week's own high-low close location and never counts daily signs.
- `QM5_41020_wti-wclose-mom` uses fixed Tuesday and Friday endpoints and a
  partial-week hold rather than all five chronological daily intervals.
- `QM5_41065` through `QM5_41074` and `QM5_41082` classify multi-week return
  paths, magnitudes, ranges, or settlement states; this extraction measures
  within-one-week daily directional breadth.
- `QM5_41029` through `QM5_41036` split session and overnight components; this
  extraction uses adjacent close-to-close returns without flow decomposition.
- `QM5_13150`, `QM5_20244`, and `QM5_20273` use twelve monthly returns under
  monthly clocks; this extraction uses exactly five daily returns under a
  weekly clock.
- `QM5_13049_xti-1w-mom-vol` uses one five-D1 magnitude return and a rolling
  volatility-rank gate but does not count component signs.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day
  oscillator pullback, not symmetric WTI continuation.

The exact carrier, parent endpoint, five newest-week session closes, five
chronological component signs, four-of-five threshold, agreeing weekly net,
consumed weekly attempt, and next-week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_DAILY_BREADTH_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to a named-author, peer-reviewed DOI record with a complete
  read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, return orientation, session count,
  zero handling, breadth, net direction, side, risk, stop, exit, attempt, and
  stale guard are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies all runtime inputs.
  Q02 owns history, label, density, holiday attrition, and CFD-basis
  sufficiency.
- R4: `PASS`. Runtime uses timestamps, prices, logarithms, counts,
  comparisons, ATR, spread, quote, and native trade state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural own-return trend carrier, not this
weekly daily-sign breadth gate's efficacy. Q02 must retire below five completed
positions per full post-warm-up year or on nonpositive governed economics.
No failure may be rescued by accepting a four-session week, lowering the
breadth threshold, removing weekly-net confirmation, changing direction or
hold, or adding a magnitude, volatility, volume, or calendar filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
