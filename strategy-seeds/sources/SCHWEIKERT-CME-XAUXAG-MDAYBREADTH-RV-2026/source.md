---
source_id: SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026
title: XAU/XAG completed-month daily relative-sign breadth reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_daily_relative_sign_breadth_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-mdaybreadth-rv
---

# XAU/XAG Completed-Month Daily Relative-Sign Breadth Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed parents. Both parents were read completely before source approval:

- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` preserves
  Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance*
  88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus supporting
  fractional-cointegration lineage from Yaya, Vo, and Olayinka (2021),
  *Resources Policy* 72, 102045, DOI
  `10.1016/j.resourpol.2021.102045`.
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records CME Group's
  definition of the gold/silver ratio, the intermarket-spread carrier, and
  the metals' differing monetary and industrial drivers.

The durable OWNER approval is
`decisions/2026-08-22_xauxag_monthly_daily_relative_sign_breadth_reversion_source_approval.md`,
committed before this extraction at `6b0270433`. No new online page, blocked
content, inferred table value, or unrecorded source is used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior may be state dependent rather than governed by one constant
cointegrating vector. The supporting fractional-cointegration lineage also
supports treating gold and silver as related but not identical price series.
CME defines the gold/silver ratio as gold price divided by silver price,
presents it as an intermarket spread, and explains why the legs can diverge as
gold's monetary/safe-haven sensitivity and silver's industrial sensitivity
change.

The sources do not establish that broad daily participation in a one-month
gold/silver-ratio displacement predicts reversal. They do not specify two
17-to-23-session calendar months, a parent-final anchor, daily relative-return
sign counting, strict majority, endpoint agreement, a one-month hold,
equal-notional sizing, Darwinex continuous CFDs, fixed cash risk, ATR stops,
spread caps, persistent attempt state, or portfolio behavior. Those are
transparent QM hypotheses. No source alpha, Sharpe ratio, drawdown, density,
hedge ratio, neutrality, cost, CFD equivalence, or portfolio-correlation result
is imported.

## Bounded QM Mechanization

On the first tradable synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct the two immediately preceding
consecutive completed months. Each month must contain 17 through 23 unique
synchronized close pairs. Let `P` be the parent month's final synchronized
log ratio and let `Q[0]...Q[n-1]` be every chronological synchronized log ratio
in the newest completed month:

```text
P    = ln(XAU_parent_final) - ln(XAG_parent_final)
Q[i] = ln(XAU_i) - ln(XAG_i)

d[0] = Q[0] - P
d[i] = Q[i] - Q[i-1], i=1...n-1
net  = Q[n-1] - P

2 * count(d[i] > 0) > n and net > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

2 * count(d[i] < 0) > n and net < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

All close pairs complete before the decision month begins. A zero relative
return remains in `n` but contributes to neither directional count. A tie,
non-majority, net equality, majority/net disagreement, asynchronous pair,
mixed month label, invalid price, incomplete package, or current-month
observation consumes the month flat. Relative-return magnitude does not affect
eligibility or sizing.

## Exact Event Contract

1. Derive the current broker `yyyymm` from the synchronized host/companion D1
   bar time and require entry within 180 elapsed minutes of the raw host bar's
   open.
2. Require the immediately preceding synchronized bar to belong to the prior
   month, proving the first tradable bar of the new month. Derive the newest
   completed month and its consecutive parent across year boundaries.
3. Within a fixed 70-bar buffer, require 17 through 23 unique synchronized D1
   timestamps in each completed month, strict reverse-time chronology,
   positive finite closes, exact month membership, and no current-month data.
4. Use the parent month's chronological final ratio as the first anchor and
   include every newest-month close pair exactly once. Count strict relative-
   return signs while retaining equality in the denominator. Require a strict
   majority and an endpoint displacement with the same strict sign.
5. Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. No retry is allowed that month.
6. Fade the agreeing sign with one equal-absolute-notional opposite-leg
   package. Combined normalized hard-stop risk is capped at aggregate
   `RISK_FIXED=1000`; each leg receives a frozen `3.5 * ATR(20,D1)` stop and
   no target.
7. Close both legs on the first tick of a later broker month, with a forty-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker returned `CLEAN` across 4,608 registry
identities, 1,280 root cards, and 45 Strategy-Wiki nodes. Evidence is
`artifacts/qm5_xauxag_mdaybreadth_rv_preallocation_dedup_20260822.json`.

The nearest systems do not share the complete identity:

- `QM5_41085_xauxag-wdaybreadth-rv` uses one exact five-session week, a
  four-of-five rule, and a one-week hold rather than two complete calendar
  months, all newest-month relative returns, strict majority, and a next-month
  hold.
- `QM5_20275_gsr-runfade` classifies a fixed six-return rolling run rather than
  every synchronized relative return in one completed calendar month.
- rolling ratio/residual cards (`QM5_12577`, `QM5_20157`, `QM5_20161`,
  `QM5_20263`, and `QM5_20268`) estimate a center, regression, scale, score, or
  tail; this extraction estimates none.
- `QM5_41103`, `QM5_41104`, `QM5_41109`, and `QM5_41110` use monthly ratio
  range, location, or distribution geometry rather than adjacent relative-
  return signs.
- session-flow cards (`QM5_41030`, `QM5_41040`, and `QM5_41057`) decompose
  overnight/session returns rather than synchronized close-to-close monthly
  paths.
- `QM5_41111_wti-mdaybreadth-mom` follows an outright WTI daily-sign majority;
  this extraction fades a two-metal relative move with opposite equal-notional
  legs.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol XNG
  oscillator pullback.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, every newest-
month relative-return sign, equality-inclusive denominator, strict majority,
same-sign endpoint displacement, contrarian package direction, consumed
monthly attempt, equal-notional aggregate-risk package, and next-month exit
are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK`. One bounded child
  source ID preserves named peer-reviewed DOI and official-exchange lineage
  and discloses the untested daily-breadth condition.
- R2: `PASS`. Synchronized month labels, endpoints, return orientation,
  equality handling, strict majority, endpoint agreement, sides, attempt,
  risk, stops, atomicity, spread gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs. Q02 owns history, holiday attrition, costs, financing,
  density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms, counting,
  comparisons, ATR, quotes, positions, deals, and persistent terminal state;
  no trained logic, banned signal, external feed, grid, martingale, scale-in,
  or pyramid exists.

## Claim And Kill Boundary

The sources support testing a state-dependent gold/silver relative-value
carrier, not this monthly breadth rule's profitability. Expected cadence is
approximately seven to ten completed packages per full post-warm-up year. Q02
must retire below five completed packages per full year, at zero trades or
nonpositive governed economics. No failure may be rescued by changing session
bounds, deleting flat returns, accepting majority equality, removing endpoint
agreement, changing side or hold, or adding a fitted center, volatility,
volume, event, calendar, external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
