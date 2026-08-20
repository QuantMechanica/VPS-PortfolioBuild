---
source_id: SCHWEIKERT-CME-XAUXAG-WDECAY-RV-2026
title: Gold-silver completed-week relative-move deceleration reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-20_xauxag_weekly_deceleration_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-20
created_by: Research+Development
cards_extracted:
  - xauxag-wdecay-rv
---

# XAU/XAG Completed-Week Deceleration Reversion Source Packet

## Approved Source Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed repository parents, both read completely before the durable source
approval was written:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Schweikert (2018), "Are gold and silver cointegrated? New evidence from
   quantile cointegrating regressions," *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus the supplemental robust
   cointegration lineage recorded there.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group,
   "Gold & Silver Ratio Spread" and its governed related material.

The durable OWNER approval is
`decisions/2026-08-20_xauxag_weekly_deceleration_reversion_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The peer-reviewed lineage supports testing a potentially state-dependent
long-run gold/silver relationship rather than assuming one constant
equilibrium. The CME lineage defines the gold/silver ratio as gold price
divided by silver price and supports treating the instruments as one
intermarket relative-value carrier. Gold and silver share precious-metals
drivers while differing in monetary, safe-haven, and industrial sensitivity.

These findings justify a falsifiable relative-price reversion hypothesis.
They do not establish that two same-sign weekly moves are exhausted when the
newest magnitude is smaller, that the inverse package will converge, or that a
Darwinex CFD package is neutral or uncorrelated.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of each Monday-anchored broker week,
align the three immediately preceding completed week-end closes for XAU and
XAG. For week-end index 1 newest through 3 oldest, define:

```text
s_i   = ln(XAU_close_i) - ln(XAG_close_i)
r_new = s_1 - s_2
r_old = s_2 - s_3
```

Require both returns finite and non-zero, `sign(r_new)=sign(r_old)`, and
`abs(r_new)<abs(r_old)`. Two positive but decelerating moves open SELL XAU /
BUY XAG. Two negative but decelerating moves open BUY XAU / SELL XAG. Close at
the first later Monday anchor or after ten calendar days.

The weekly horizon, exact endpoint reconstruction, two-return count, strict
same-sign and deceleration conditions, inverse sides, CFD carrier,
equal-notional target, aggregate fixed-risk cap, ATR stops, spread caps,
consumed-attempt ledger, next-week exit, and stale guard are transparent QM
choices. They are not attributed to the sources. No source return, alpha,
drawdown, density, CFD equivalence, neutrality, or portfolio-correlation
statistic is imported.

## Exact Event Contract

For positive finite synchronized completed week-end closes:

```text
s1 = ln(XAU_newest) - ln(XAG_newest)
s2 = ln(XAU_middle) - ln(XAG_middle)
s3 = ln(XAU_oldest) - ln(XAG_oldest)

r_new = s1 - s2
r_old = s2 - s3

r_old > 0 and r_new > 0 and abs(r_new) < abs(r_old)
    => SELL XAU, BUY XAG
r_old < 0 and r_new < 0 and abs(r_new) < abs(r_old)
    => BUY XAU, SELL XAG
otherwise
    => FLAT
```

Strict inequality is load-bearing. Equality is flat. The two weekly intervals
share only their boundary endpoint and do not overlap in return time. The
current decision-week open, high, low, or close is excluded. There is no
threshold, standardization, regression, order statistic, channel, range,
weekday direction, external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,553
registry rows and 625 root cards. Existing XAU/XAG convergence systems use
rolling scores, fitted residuals, tails, channels, calendar ranks, daily
five-return exhaustion, within-day flow decompositions, opposed weekend gaps,
or weekly NR7 breakouts. None uses exactly two adjacent completed broker-week
relative returns, requires strict same-sign magnitude decay, immediately
opens the inverse two-leg package, and owns exactly the next broker week.

The three synchronized week ends, chronological return orientation, strict
same-sign test, strict absolute deceleration, inverse sides, consumed weekly
attempt, and next-week exit are jointly load-bearing. Changing any one creates
a different identity.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_EXHAUSTION_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to a named-author peer-reviewed DOI record and a governed
  CME exchange packet; no performance claim transfers.
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
weekly deceleration fade's efficacy. Q02 must retire the card below five
completed packages per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing the number of weeks, accepting equality,
acceleration, or opposed signs, changing direction, adding a threshold or
fitted center, changing the hold, or adding a trend/calendar filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or neutrality claim.
