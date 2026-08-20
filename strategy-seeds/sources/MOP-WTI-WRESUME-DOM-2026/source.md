---
source_id: MOP-WTI-WRESUME-DOM-2026
title: WTI completed-week resumption-dominance momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-20_wti_weekly_resumption_dominance_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-20
created_by: Research+Development
cards_extracted:
  - wti-wresume-dom
---

# WTI Completed-Week Resumption-Dominance Source Packet

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
`decisions/2026-08-20_wti_weekly_resumption_dominance_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The paper documents positive own-return continuation and mechanically maps
the sign of an instrument's past return to the next holding-period direction.
It supports a falsifiable WTI trend hypothesis and a symmetric long/short
direction map.

The paper's tested formation and holding horizons are monthly. It does not
establish a WTI-only weekly premium, a three-week resume/counter/resume path,
or continuation after the resumed move strictly dominates the intervening
counterweek. It does not test a Darwinex continuous CFD, fixed-dollar ATR
risk, spread ceiling, persistent restart state, or the QM portfolio. Those are
transparent QM choices; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
reconstruct the four immediately preceding completed week-end closes. For
week-end index 1 newest through 4 oldest, define chronological returns:

```text
r_oldest  = ln(close_3 / close_4)
r_counter = ln(close_2 / close_3)
r_resume  = ln(close_1 / close_2)
```

Require finite, non-zero returns with `sign(r_oldest)=sign(r_resume)`, the
middle return strictly opposed, and `abs(r_resume)>abs(r_counter)`. A
positive/negative/positive path buys WTI. A negative/positive/negative path
sells WTI. Close at the first later Monday anchor or after ten calendar days.

The weekly horizon, exact endpoint reconstruction, three-return count,
outer-sign equality, opposed-middle and strict dominance conditions,
continuation side, CFD carrier, fixed-risk budget, ATR stop, spread cap,
consumed-attempt ledger, next-week exit, and stale guard are QM choices. They
are not attributed to the source. No source alpha, Sharpe ratio, drawdown,
density, CFD equivalence, or portfolio-correlation statistic is imported.

## Exact Event Contract

For positive finite completed week-end closes:

```text
r_oldest > 0 and r_counter < 0 and r_resume > 0
and abs(r_resume) > abs(r_counter)
    => BUY XTIUSD.DWX

r_oldest < 0 and r_counter > 0 and r_resume < 0
and abs(r_resume) > abs(r_counter)
    => SELL XTIUSD.DWX

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

The deterministic pre-allocation checker returned `CLEAN` across 4,558
registry rows and 625 root cards. The nearest direct-WTI weekly siblings do
not share the complete identity. `QM5_41065` acts on any two-week sign handoff;
this card requires a third older week whose sign is restored and requires the
resumed move to dominate the counterweek. `QM5_41069` enters before the
resumption week, after a smaller countermove, whereas this card waits for a
separate completed recovery. `QM5_41068` and `QM5_41070` require the newest
two weeks to have the same sign. Monthly, volatility-ranked, range-breakout,
calendar, and relative-basket WTI families use different clocks or state.

The four completed week ends, chronological return orientation, outer-sign
equality, opposed middle, strict resumed-move dominance, continuation side,
consumed weekly attempt, and next-week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_RESUMPTION_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to a named-author, peer-reviewed DOI record with a complete
  read and explicit WTI membership; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, return orientation, path state,
  side, risk, stop, exit, attempt, and stale guard are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 state supplies all runtime inputs.
  Q02 owns history, label, density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, prices, logarithms, comparisons,
  arithmetic, ATR, spread, quote, and native trade state only; no trained
  model, external feed, banned signal, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a structural own-return trend carrier, not this
weekly path-and-dominance gate's efficacy. Q02 must retire the card below five
completed positions per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing the number of weeks, accepting equality, removing
the counterweek or dominance gate, changing direction or hold, or adding a
threshold, volatility, volume, or calendar filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.

