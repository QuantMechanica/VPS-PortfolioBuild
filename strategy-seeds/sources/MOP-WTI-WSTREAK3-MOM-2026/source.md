---
source_id: MOP-WTI-WSTREAK3-MOM-2026
title: WTI fresh three-week sign-streak momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-20_wti_three_week_sign_streak_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-20
created_by: Research+Development
cards_extracted:
  - wti-wstreak3-mom
---

# WTI Fresh Three-Week Sign-Streak Momentum Source Packet

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
`decisions/2026-08-20_wti_three_week_sign_streak_momentum_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The paper documents positive own-return continuation and mechanically maps
the sign of an instrument's past return to the next holding-period direction.
It supports a falsifiable WTI trend hypothesis and a symmetric long/short
direction map.

The paper's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a fresh three-week sign streak, or an
opposite-sign predecessor condition. It does not test a Darwinex continuous
CFD, fixed-dollar ATR risk, spread ceiling, persistent restart state, or the
QM portfolio. Those are transparent QM choices; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
reconstruct five consecutive completed broker-week ending closes from native
D1 history. Require exact seven-calendar-day anchor adjacency, three to five
strictly ordered sessions in every contributing week, and one uniform raw or
governed `+1`-day energy-label convention.

Let `C0` be the newest completed week-ending close and `C4` the oldest. Define
four adjacent, non-overlapping weekly returns:

```text
r0 = ln(C0 / C1)
r1 = ln(C1 / C2)
r2 = ln(C2 / C3)
r3 = ln(C3 / C4)

r0 > 0 and r1 > 0 and r2 > 0 and r3 < 0  => BUY XTIUSD.DWX
r0 < 0 and r1 < 0 and r2 < 0 and r3 > 0  => SELL XTIUSD.DWX
otherwise                                  => FLAT
```

The strict opposite sign of `r3` makes `r0..r2` the first completed
three-week streak after a contrary week. This is an event, not a rolling
every-week trend exposure: after a fourth same-sign week, the shifted
predecessor is no longer opposite and the next attempt stays flat.

The weekly horizon, exact endpoint reconstruction, streak length, predecessor
transition, continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap,
consumed-attempt ledger, next-week exit, and stale guard are QM choices. They
are not attributed to the source. No source alpha, Sharpe ratio, drawdown,
density, CFD equivalence, or portfolio-correlation statistic is imported.

## Exact Event Contract

All current decision-week OHLC is excluded. Each return uses two consecutive
completed week-ending closes; the four intervals share endpoints but never
overlap in time. Every endpoint must be positive and finite. Exact zero,
missing or nonconsecutive anchors, invalid session counts, a mixed label
convention, or any sign path other than strict `-+++` or `+---` is flat.

One exact Monday-anchor attempt is persisted before history, signal, news,
spread, quote, ATR, sizing, or order gates. The position uses one frozen
`3.5 * ATR(20,D1)` hard stop, one `RISK_FIXED=1000` budget, no target, and a
1,500-point spread ceiling. The first tick of a later broker week closes the
position; ten calendar days is a stale repair only.

There is no return-magnitude threshold, volatility state, SMA, regression,
rank, channel, weekly high/low geometry, current-week breakout, weekday
direction, external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,561
registry rows and 625 root cards. The nearest WTI weekly siblings do not share
the complete identity.

`QM5_41065_wti-wflip-mom` enters directly after one sign reversal between two
weeks. `QM5_41068_wti-waccel-mom` and `QM5_41070_wti-wdecel-mom` compare two
same-sign weekly return magnitudes. `QM5_41069_wti-wpull-trend`,
`QM5_41071_wti-wresume-dom`, and `QM5_41072_wti-wcounter-dom` require an
opposed week inside their newest path and impose trend or magnitude dominance.
This extraction instead requires three newest strict same-sign returns, one
strict opposite predecessor, and ignores all magnitudes.

`QM5_41022_wti-wdual-mom` compares two intrawEEK segments inside one completed
week. `QM5_20273_wti-signrun-tr` scores a twelve-month D1 sign path and decides
monthly. Neither uses a fresh three-completed-week transition.

The five completed week-ending closes, four adjacent weekly returns, strict
`-+++` / `+---` state, next-boundary entry, consumed attempt, and same one-week
direction are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK`. One bounded source ID supplies
  lineage to a named-author, peer-reviewed DOI record with a complete read and
  explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, session counts, endpoint selection,
  return formulas, strict sign transition, side, risk, stop, exit, attempt,
  and stale guard are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies all runtime inputs.
  Q02 owns history, label, density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed closes, comparisons,
  logarithms, ATR, spread, quote, and native trade state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural own-return trend carrier, not this
fresh weekly streak gate's efficacy. Q02 must retire the card below three
completed positions per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by accepting zero, removing the opposite predecessor, changing
the streak length, adding a magnitude threshold, reversing the side, changing
the hold, or adding volatility, volume, calendar, moving-average, or external
state.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.

