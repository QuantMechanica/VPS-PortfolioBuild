---
source_id: SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026
title: Gold-silver fresh completed-week sign-streak reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_xauxag_weekly_sign_streak_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - xauxag-wstreak3-rv
---

# XAU/XAG Fresh Completed-Week Sign-Streak Reversion Source Packet

## Approved Source Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed repository parents, both read completely before durable approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus the supplemental
   robust cointegration lineage recorded there.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group,
   "Gold & Silver Ratio Spread" and its governed related material.

The durable OWNER approval is
`decisions/2026-08-21_xauxag_weekly_sign_streak_reversion_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The peer-reviewed lineage supports testing a potentially state-dependent
long-run gold/silver relationship rather than assuming one constant
equilibrium. The CME lineage defines the gold/silver ratio as gold price
divided by silver price and supports treating gold and silver as one
intermarket relative-value carrier. Gold and silver share precious-metals
drivers while differing in monetary, safe-haven, and industrial sensitivity.

These findings justify a falsifiable relative-price reversion hypothesis.
They do not establish that three same-sign completed-week relative returns are
an exhaustion event, that a fourth week will reverse, or that a Darwinex CFD
package is neutral or uncorrelated.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of each Monday-anchored broker week,
align the five immediately preceding completed week-end closes for XAU and
XAG. Let `s0` be the newest synchronized completed-week log ratio and `s4` the
oldest, with `r0=s0-s1` through `r3=s3-s4`.

Require the newest three weekly returns to have one strict common sign and the
preceding return to have the strict opposite sign. The predecessor makes the
three-week streak fresh and prevents rolling weekly re-entry during a longer
run. Fade a fresh positive streak with SELL XAU / BUY XAG and a fresh negative
streak with BUY XAU / SELL XAG. Close at the first later Monday anchor or after
ten calendar days.

The weekly horizon, exact endpoint reconstruction, fresh-streak state,
contrarian direction, CFD carrier, equal-notional target, aggregate fixed-risk
cap, ATR stops, spread caps, consumed-attempt ledger, next-week exit, and stale
guard are transparent QM choices. They are not attributed to the sources. No
source return, alpha, drawdown, density, CFD equivalence, neutrality, or
portfolio-correlation statistic is imported.

## Exact Event Contract

For positive finite synchronized completed week-end closes:

```text
s0 = ln(XAU_newest) - ln(XAG_newest)
s1 = ln(XAU_1week_older) - ln(XAG_1week_older)
s2 = ln(XAU_2weeks_older) - ln(XAG_2weeks_older)
s3 = ln(XAU_3weeks_older) - ln(XAG_3weeks_older)
s4 = ln(XAU_4weeks_older) - ln(XAG_4weeks_older)

r0 = s0 - s1
r1 = s1 - s2
r2 = s2 - s3
r3 = s3 - s4

r0 > 0 and r1 > 0 and r2 > 0 and r3 < 0
    => SELL XAU, BUY XAG
r0 < 0 and r1 < 0 and r2 < 0 and r3 > 0
    => BUY XAU, SELL XAG
otherwise
    => FLAT
```

Strict inequalities are load-bearing and exact zero is flat. The four weekly
intervals share boundary endpoints but do not overlap in return time. The
current decision-week open, high, low, or close is excluded. Return magnitude
does not affect signal or risk. There is no threshold, fitted center,
standardization, regression, order statistic, channel, range, weekday
direction, external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,565
registry rows and 625 root cards. Manual family review separates this exact
identity from:

- `QM5_20275_gsr-runfade`, which uses five newest same-sign D1 relative
  returns, a sixth-return break, and a first-counter-return exit rather than
  three completed broker weeks and a fixed one-week hold;
- `QM5_41066`, `QM5_41075`, `QM5_41076`, and `QM5_41077`, which classify two
  adjacent completed-week relative returns by sign and magnitude rather than
  requiring a fresh three-week same-sign streak;
- `QM5_41060` and `QM5_41062`, which use weekly range breakout and opposed
  weekend-gap states rather than completed-week close signs;
- `QM5_41074_wti-wstreak3-mom`, which uses the same fresh weekly sign-path
  topology on one outright WTI leg but follows the streak; this extraction
  uses a paired XAU/XAG carrier and fades the relative streak; and
- rolling ratio, OLS residual, robust-score, tail, channel, calendar-rank,
  cross-sectional-momentum, and flow-decomposition systems, none of which use
  this exact fresh completed-week relative-sign event.

The exact paired carrier, five synchronized completed week ends, chronological
return orientation, strict `-+++` or `+---` relative-sign state, contrarian
package, consumed weekly attempt, equal-notional aggregate-risk package, and
next-week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_STREAK_REVERSION_TRANSLATION_RISK`. One bounded source
  ID supplies lineage to a named-author peer-reviewed DOI record and a
  governed CME exchange packet; no performance claim transfers.
- R2: `PASS`. Exact shifts, week anchors, return orientation, state, sides,
  aggregate risk, stops, exit, attempt, and stale guard are fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs. Q02 owns synchronized-history sufficiency.
- R4: `PASS`. Runtime uses timestamps, prices, logarithms, comparisons,
  arithmetic, ATR, spread, quote, and native trade state only; no trained
  model, external feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The sources support testing a structural relative-value carrier, not this
fresh weekly sign-streak fade's efficacy. An independent-sign design reference
implies about 6.5 fresh three-week events per 52 weeks before data and
execution gates; this is a cadence hypothesis, not source evidence. Q02 must
retire the card below five completed packages per full post-warm-up year or on
nonpositive governed economics. Downstream gates alone own robustness and
correlation. No failure may be rescued by changing the streak length, dropping
the opposite predecessor, following instead of fading, changing the hold, or
adding a threshold or fitted center.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or neutrality claim.
