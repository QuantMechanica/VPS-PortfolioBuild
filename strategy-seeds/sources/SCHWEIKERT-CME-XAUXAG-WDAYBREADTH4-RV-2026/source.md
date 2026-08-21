---
source_id: SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026
title: XAU/XAG completed-week daily relative-sign breadth reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_xauxag_weekly_daily_relative_sign_breadth_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - xauxag-wdaybreadth-rv
---

# XAU/XAG Completed-Week Daily Relative-Sign Breadth Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed parents, both read completely before the durable approval was written:

- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` preserves
  Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance*
  88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus supporting
  fractional-cointegration lineage.
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records CME Group's
  definition of the gold/silver ratio, the intermarket-spread carrier, and the
  metals' differing monetary and industrial drivers.

The durable OWNER approval is
`decisions/2026-08-21_xauxag_weekly_daily_relative_sign_breadth_reversion_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior may be state dependent rather than governed by one constant
cointegrating vector. CME supports expressing gold versus silver as one
intermarket relative-value carrier and explains why the legs can temporarily
diverge because their economic sensitivities differ.

The sources do not establish that broad daily participation in a one-week
gold/silver ratio move predicts reversal. They do not specify five daily
relative returns, a four-of-five breadth rule, weekly-net confirmation, a
one-week hold, equal-notional sizing, Darwinex continuous CFDs, fixed cash
risk, ATR stops, spread caps, persistent attempt state, or portfolio behavior.
Those are transparent QM hypotheses. No source alpha, Sharpe ratio, drawdown,
density, hedge ratio, neutrality, cost, CFD equivalence, or portfolio-
correlation result is imported.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of a new Monday-anchored broker week,
reconstruct the final synchronized XAU/XAG close pair of the parent week plus
exactly five chronological synchronized close pairs in the immediately
completed broker week. Define the synchronized log ratio at each endpoint:

```text
q_t = ln(XAU_t) - ln(XAG_t)
d_i = q_i - q_(i-1), i = 1..5
weekly_net = q_5 - q_0
```

Count strictly positive and strictly negative `d_i`; a zero counts toward
neither side. Fade only a broadly shared completed-week ratio displacement:

```text
positive_count >= 4 and weekly_net > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

negative_count >= 4 and weekly_net < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

The same-sign full-week conjunction prevents one opposed large daily move from
reversing the aggregate displacement. Magnitudes otherwise do not affect
eligibility, direction, or sizing. A non-five-session week, asynchronous
endpoint, zero/equality state, breadth/net disagreement, missing parent close,
or invalid price consumes the week flat. No current decision-week price enters
the signal.

## Exact Event Contract

1. Derive the current broker Monday anchor from the raw host D1 bar time and
   require entry within 180 elapsed minutes of that bar's open.
2. Require the immediately completed week to contain exactly five synchronized
   host/companion D1 timestamps and require one older synchronized parent-week
   final close. Week anchors must be consecutive.
3. Compute five adjacent, chronological relative log returns and the exact
   parent-final-to-newest-final weekly relative return. Require strict four-of-
   five sign breadth and a weekly net with the same strict sign.
4. Persist the current week anchor before history, signal, spread, quote, ATR,
   sizing, news, or order gates. No retry is allowed in that week.
5. Trade one equal-absolute-notional opposite-leg package with aggregate
   `RISK_FIXED=1000`, frozen `3.5 * ATR(20,D1)` per-leg stops, and no target.
6. Close both legs on the first tick of a later broker week, with a ten-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The deterministic checker returned `CLEAN` across 4,572 registry rows and 625
root cards. The nearest gold/silver systems do not share the complete identity:

- rolling ratio/residual cards (`QM5_12577`, `QM5_20157`, `QM5_20161`,
  `QM5_20263`, and `QM5_20268`) estimate a center, regression, scale, score, or
  tail; this extraction estimates none;
- `QM5_41079_xauxag-wclose-extreme-rv` ranks the final ratio close against
  three to five closes inside the completed week, uses no parent close, and
  never counts adjacent relative-return signs;
- `QM5_41083_xauxag-wlegdiv-rv` requires the two individual metals' complete-
  week returns to have opposite signs and has no within-week path state;
- `QM5_41030`, `QM5_41040`, and `QM5_41057` decompose overnight and session
  relative flows rather than use five adjacent close-to-close relative returns;
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify the ratio path
  across two or three completed weeks rather than breadth inside one exact
  five-session week; and
- `QM5_41084_wti-wdaybreadth-mom` applies a same-topology breadth condition to
  one directional WTI carrier and follows it; this extraction trades two
  synchronized metals, fades their relative move, and targets equal notionals.

The exact paired carrier, parent-week endpoint, exact five-session synchronized
week, five relative-return signs, strict four-of-five breadth, same-sign weekly
net, contrarian package direction, consumed weekly attempt, equal-notional
aggregate-risk package, and next-week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_DAILY_BREADTH_TRANSLATION_RISK`. One bounded child
  source ID preserves named peer-reviewed DOI and official-exchange lineage
  and discloses the untested daily-breadth condition.
- R2: `PASS`. Exact synchronized endpoints, return orientation, zero handling,
  breadth/net conjunction, sides, attempt, risk, stops, atomicity, spread gates,
  and lifecycle are mechanical and fixed.
- R3: `PASS_WITH_EXACT_FIVE_SESSION_SYNCHRONIZATION_AND_CFD_BASIS_RISK`.
  Registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state
  provide all runtime inputs.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms, counting,
  comparisons, ATR, quotes, positions, deals, and persistent terminal state;
  no trained logic, banned signal, external feed, grid, martingale, scale-in,
  or pyramid exists.

## Claim And Kill Boundary

The sources support testing a state-dependent gold/silver relative-value
carrier, not this breadth rule's profitability. Expected cadence is
approximately ten to twenty completed packages per full post-warm-up year.
Q02 must retire below five completed packages per full year, at zero trades or
nonpositive governed economics. No failure may be rescued by accepting a
four-session week, lowering the breadth threshold, removing weekly-net
agreement, changing the side or hold, or adding a fitted center, volatility,
volume, calendar, or external state.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
