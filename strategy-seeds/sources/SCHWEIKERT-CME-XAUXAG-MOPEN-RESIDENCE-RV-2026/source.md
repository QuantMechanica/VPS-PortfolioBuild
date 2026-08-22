---
source_id: SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026
title: XAU/XAG completed-month fixed-open residence reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_open_residence_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-mopen-residence-rv
---

# XAU/XAG Completed-Month Fixed-Open Residence Reversion Source Packet

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
`decisions/2026-08-22_xauxag_monthly_open_residence_reversion_source_approval.md`,
committed before this extraction at `a7d733f31`. No new online page, blocked
content, inferred table value, or unrecorded source is used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior may be state dependent rather than governed by one constant
cointegrating vector. The supporting fractional-cointegration lineage also
supports treating gold and silver as related but non-identical price series.
CME defines the gold/silver ratio as gold price divided by silver price,
presents it as an intermarket spread, and explains why the legs can diverge as
gold's monetary/safe-haven sensitivity and silver's industrial sensitivity
change.

The sources do not establish that spending at least three quarters of a
completed month on one side of its first relative close predicts reversal.
They do not specify a 17-to-23-session calendar month, an immutable first-close
anchor, a three-quarter inclusive count, a final-close side confirmation, a
one-month contrarian hold, equal-notional sizing, Darwinex continuous CFDs,
fixed cash risk, ATR stops, spread caps, persistent attempt state, or
portfolio behavior. Those are transparent QM hypotheses. No source alpha,
Sharpe ratio, drawdown, density, hedge ratio, neutrality, cost, CFD
equivalence, or portfolio-correlation result is imported.

## Bounded QM Mechanization

On the first tradable synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct every synchronized close pair in the
immediately completed calendar month. Require 17 through 23 pairs and order
their gold-minus-silver log ratios oldest to newest:

```text
s[i]     = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..n-1
anchor   = s[0]
m        = n-1
above    = count(s[i] > anchor for i=1..n-1)
below    = count(s[i] < anchor for i=1..n-1)
required = ceil(3*m/4) = (3*m+3)//4

above >= required and s[n-1] > anchor
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

below >= required and s[n-1] < anchor
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

The first close is used only as the fixed anchor. Exact later ties consume a
denominator observation but count toward neither side. Under the locked
session bound, `m` is 16 through 22 and `required` is 12 through 17. Residence
surplus and endpoint displacement never change direction, sizing, stops, or
lifecycle.

## Exact Event Contract

1. Derive the current broker `yyyymm` from the synchronized host/companion D1
   bar time and require entry within 180 elapsed minutes of the raw host bar's
   open.
2. Require the immediately preceding synchronized bar to belong to the prior
   month, proving the first tradable bar of the new month. Derive the exact
   immediately completed month across year boundaries.
3. Within a fixed 45-bar buffer, require 17 through 23 unique synchronized D1
   timestamps in that month, strict reverse-time history order, positive
   finite closes, exact month membership, and no current-month data.
4. Reverse the ratios into chronological order. Freeze the first ratio as the
   anchor, count every later ratio strictly above and below it, set
   `required=(3*(n-1)+3)//4`, and require the final ratio to remain strictly on
   the qualifying side. Every nonqualifying or malformed state remains flat.
5. Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. No retry is allowed that month.
6. Fade the qualifying residence side with one equal-absolute-notional
   opposite-leg package. Combined normalized hard-stop risk is capped at
   aggregate `RISK_FIXED=1000`; each leg receives a frozen
   `3.5 * ATR(20,D1)` stop and no target.
7. Close both legs on the first tick of a later broker month, with a forty-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,619 registry identities, 1,288 repository cards, and 45 Strategy-Wiki
nodes. Evidence is
`artifacts/qm5_xauxag_mopen_residence_rv_preallocation_dedup_20260822.json`.

Manual semantic review finds a new mechanic:

- `QM5_41112_xauxag-mdaybreadth-rv` counts signs of adjacent relative daily
  returns. This extraction counts relative close levels against one fixed
  first-close anchor.
- `QM5_41110_xauxag-moutside-res-rv` uses the prior completed month's high/low
  range as two boundaries. This extraction has no parent month and only one
  within-month anchor.
- `QM5_41119_xauxag-mclose-quartile-rv` ranks only the final close against the
  completed month's close set. This extraction counts the entire later path
  and performs no final-close rank.
- `QM5_41104_xauxag-mmedian-shift-rv` and
  `QM5_41109_xauxag-mmean-median-rv` estimate block or whole-month location
  statistics. This extraction estimates no center.
- weekly flow, streak, acceleration, closing-extreme, and close-location
  families use different return decompositions, clocks, and boundaries.
- rolling ratio/residual cards (`QM5_12577`, `QM5_20157`, `QM5_20161`,
  `QM5_20263`, and `QM5_20268`) estimate a center, regression, scale, score,
  or empirical tail; this extraction estimates none.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, immutable first-close anchor, exhaustive
strict later-close residence counts, fixed ceiling-three-quarter threshold,
final-close side confirmation, contrarian package, consumed monthly attempt,
equal-notional aggregate-risk package, and next-month exit are jointly
load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_FIXED_OPEN_RESIDENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_OPEN_RESIDENCE_TRANSLATION_RISK`. One bounded child source
  ID preserves named peer-reviewed DOI and official-exchange lineage and
  discloses the untested residence gate.
- R2: `PASS`. Synchronized month labels, chronology, anchor, denominator,
  strict counts, integer threshold, final-side rule, sides, attempt, risk,
  stops, atomicity, spread gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs. Q02 owns history, holiday attrition, costs, financing,
  density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms, integer
  counts, comparisons, ATR, quotes, positions, deals, and persistent terminal
  state; no trained logic, banned signal, external feed, grid, martingale,
  scale-in, or pyramid exists.

## Claim And Kill Boundary

The sources support testing a state-dependent gold/silver relative-value
carrier, not this fixed-open residence rule's profitability. Expected cadence
is approximately six to nine completed packages per full post-warm-up year.
Q02 must retire below five completed packages per full year, at zero trades,
or with nonpositive governed economics. No failure may be rescued by changing
the residence fraction, assigning ties, changing session bounds, changing
side or hold, or adding a fitted center, scale, distance, return, volatility,
volume, event, calendar, external, or prior-result state.

Opposite equal-notional legs are designed to reduce common outright-metal
direction but do not prove neutrality or low portfolio correlation. Q09 alone
owns the realized portfolio finding.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
