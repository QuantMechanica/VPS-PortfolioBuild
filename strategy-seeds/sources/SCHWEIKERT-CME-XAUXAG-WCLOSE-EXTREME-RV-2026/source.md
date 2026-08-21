---
source_id: SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026
title: Gold-silver completed-week closing-extreme reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_xauxag_weekly_closing_extreme_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - xauxag-wclose-extreme-rv
---

# XAU/XAG Completed-Week Closing-Extreme Reversion Source Packet

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
`decisions/2026-08-21_xauxag_weekly_closing_extreme_reversion_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

The peer-reviewed lineage supports testing a potentially state-dependent
long-run gold/silver relationship rather than assuming one constant
equilibrium. The CME lineage defines the gold/silver ratio as gold price
divided by silver price and supports treating gold and silver as one
intermarket relative-value carrier. Gold and silver share precious-metals
drivers while differing in monetary, safe-haven, industrial, and business-
cycle sensitivity.

These findings justify a falsifiable relative-price reversion hypothesis.
They do not establish that a completed broker week ending at its highest or
lowest synchronized daily ratio close will reverse, that the next week is the
correct horizon, or that a Darwinex CFD package is neutral or uncorrelated.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of each Monday-anchored broker week,
align every completed XAU and XAG D1 close from the immediately preceding
broker week. Require an exact synchronized set of three to five sessions. For
each oldest-to-newest pair define `s[i]=ln(XAU_close[i])-ln(XAG_close[i])`.

If the newest ratio close is strictly greater than every earlier ratio close
in that week, fade the upper closing extreme with SELL XAU / BUY XAG. If it
is strictly less than every earlier ratio close, fade the lower closing
extreme with BUY XAU / SELL XAG. An equality or an interior newest close is
flat. Close at the first later Monday anchor or after ten calendar days.

The weekly horizon, within-week close-rank state, contrarian direction, CFD
carrier, equal-notional target, aggregate fixed-risk cap, ATR stops, spread
caps, consumed-attempt ledger, next-week exit, and stale guard are transparent
QM choices. They are not attributed to the sources. No source return, alpha,
drawdown, density, CFD equivalence, neutrality, or portfolio-correlation
statistic is imported.

## Exact Event Contract

Let the immediately completed week contain `n` synchronized positive finite
daily close pairs ordered oldest to newest, where `3 <= n <= 5`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..n-1

upper = s[n-1] > s[i] for every i=0..n-2
lower = s[n-1] < s[i] for every i=0..n-2

upper => SELL XAU, BUY XAG
lower => BUY XAU, SELL XAG
otherwise => FLAT
```

All timestamps belong to the exact prior Monday anchor and match across the
two instruments. The current decision-week open, high, low, or close is
excluded. Only completed D1 closes are ranked; intraday highs and lows are not
substitutes. Strict inequalities are load-bearing. Excursion distance does
not affect signal or risk. There is no rolling center, scale estimator,
threshold, regression, return-sign path, weekly-range comparison, current-
week breakout, external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,566
registry rows and 625 root cards. Manual family review separates this exact
identity from:

- rolling ratio z-score, OLS residual, median/MAD, conditional-quantile, and
  empirical-tail systems, which estimate state across multiweek windows;
- `QM5_20265_gsr-fail-rv`, which requires a daily channel break and a later
  return inside;
- `QM5_20275_gsr-runfade`, which classifies six daily relative-return signs
  and exits on a counter-return;
- `QM5_41060_xauxag-week-nr7-brk`, which compares seven completed weekly
  ranges and follows a fresh next-week close breakout;
- `QM5_41066`, `QM5_41075`, `QM5_41076`, `QM5_41077`, and `QM5_41078`, which
  classify adjacent completed-week returns by sign, magnitude, or streak
  topology instead of ranking the daily endpoints within one completed week;
  and
- flow-decomposition, weekend-gap, calendar, cross-sectional-rank, and moment
  families, none of which use this exact within-week closing-rank event.

The exact paired carrier, immediately preceding Monday-anchored broker week,
complete synchronized three-to-five-session set, strict newest ratio rank,
contrarian package, consumed weekly attempt, aggregate fixed risk, and next-
week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_CLOSING_EXTREME_TRANSLATION_RISK`. One bounded source
  ID supplies lineage to a named-author peer-reviewed DOI record and a
  governed CME exchange packet; no performance claim transfers.
- R2: `PASS`. Exact timestamps, week anchors, session count, ratio orientation,
  strict rank, sides, aggregate risk, stops, exit, attempt, and stale guard are
  fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs. Q02 owns synchronized-history sufficiency.
- R4: `PASS`. Runtime uses timestamps, prices, logarithms, comparisons,
  arithmetic, ATR, spread, quote, and native trade state only; no trained
  model, external feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The sources support testing a structural relative-value carrier, not this
weekly closing-extreme fade's efficacy. With three to five sessions per week,
an exchangeable-rank design reference implies the last close is one of the
two extremes in roughly 40 to 67 percent of weeks; serial dependence and
execution gates can materially change that rate. This is a cadence hypothesis,
not source evidence. Q02 must retire the card below five completed packages
per full post-warm-up year or on nonpositive governed economics. Downstream
gates alone own robustness and correlation.

No failure may be rescued by weakening strict rank, adding a distance
threshold, replacing closes with highs/lows, using current-week data, changing
the hold, or adding a fitted center, beta, calendar, trend, or volatility
filter.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or neutrality claim.
