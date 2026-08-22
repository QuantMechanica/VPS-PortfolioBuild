---
source_id: SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026
title: XAU/XAG completed-month late-half dominance reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_late_half_dominance_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-mlatehalf-dom-rv
---

# XAU/XAG Completed-Month Late-Half Dominance Reversion Source Packet

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
`decisions/2026-08-22_xauxag_monthly_late_half_dominance_reversion_source_approval.md`,
committed before this extraction at `3da399186`. No new online page, blocked
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

The sources do not establish that strict late-half relative-return dominance
inside one completed calendar month predicts reversal. They do not specify
two 17-to-23-session calendar months, a parent-final anchor, a deterministic
floor-half split, a one-month contrarian hold, equal-notional sizing, Darwinex
continuous CFDs, fixed cash risk, ATR stops, spread caps, persistent attempt
state, or portfolio behavior. Those are transparent QM hypotheses. No source
alpha, Sharpe ratio, drawdown, density, hedge ratio, neutrality, cost, CFD
equivalence, or portfolio-correlation result is imported.

## Bounded QM Mechanization

On the first tradable synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct the two immediately preceding
consecutive completed months. Each month must contain 17 through 23 unique
synchronized close pairs. Let `P` be the parent month's final synchronized log
ratio and let `Q[0]...Q[n-1]` be every chronological synchronized log ratio in
the newest completed month:

```text
P    = ln(XAU_parent_final) - ln(XAG_parent_final)
Q[i] = ln(XAU_i) - ln(XAG_i)
h    = floor(n / 2)

early = Q[h-1] - P
late  = Q[n-1] - Q[h-1]

abs(late) > abs(early) and late > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

abs(late) > abs(early) and late < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

Under the locked session bound, the early block contains eight through eleven
adjacent relative returns and the late block nine through twelve. The shared
midpoint ratio is an endpoint and anchor, not a duplicated return, so the
partition is exhaustive and non-overlapping. Equality, a zero late return,
non-dominance, asynchronous history, mixed month labels, an invalid split,
invalid prices, an incomplete package, or a current-month observation consumes
the month flat. The early-half sign and full-month endpoint sign do not affect
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
4. Use the parent month's chronological final ratio as the first anchor.
   Order the newest-month ratios chronologically, set `h=floor(n/2)`, compute
   the two cumulative blocks exactly as specified, and require strict
   late-half absolute dominance. Equality and a zero late half remain flat.
5. Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. No retry is allowed that month.
6. Fade the late-half sign with one equal-absolute-notional opposite-leg
   package. Combined normalized hard-stop risk is capped at aggregate
   `RISK_FIXED=1000`; each leg receives a frozen `3.5 * ATR(20,D1)` stop and
   no target.
7. Close both legs on the first tick of a later broker month, with a forty-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,615 registry identities, 1,286 repository cards, and 45 Strategy-Wiki
nodes. Evidence is
`artifacts/qm5_xauxag_mlatehalf_dom_rv_preallocation_dedup_20260822.json`.

Manual semantic review finds a new mechanic:

- `QM5_41113_xauxag-mhalfagree-rv` requires unanimity across two cumulative
  halves and ignores relative magnitude. This extraction requires late-half
  magnitude dominance, accepts an opposed early half, and rejects same-sign
  paths whose early half is at least as large.
- `QM5_41116_xauxag-mthirdvote-rv` uses three magnitude-blind cumulative
  block votes. This extraction uses two halves, no vote, and a load-bearing
  magnitude ordering.
- `QM5_41112_xauxag-mdaybreadth-rv` counts every adjacent relative-return
  sign and requires endpoint agreement. This extraction uses two cumulative
  halves and no endpoint-agreement filter.
- `QM5_41117_wti-mlatehalf-dom-mom` applies the abstract dominance shape to
  one WTI series, follows the late sign, and owns one position. This extraction
  measures synchronized XAU-minus-XAG returns, fades the late sign, and owns
  an opposite equal-notional basket.
- `QM5_20260_xauxag-mom-vote` votes one-, three-, and twelve-month
  cross-sectional ranks and follows the winner rather than partitioning one
  completed month and fading a late relative displacement.
- rolling ratio/residual cards (`QM5_12577`, `QM5_20157`, `QM5_20161`,
  `QM5_20263`, and `QM5_20268`) estimate a center, regression, scale, score,
  or tail; this extraction estimates none.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, deterministic
floor-half split, exhaustive adjacent-return partition, strict late-half
absolute dominance, contrarian late-sign package direction, consumed monthly
attempt, equal-notional aggregate-risk package, and next-month exit are jointly
load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_LATE_HALF_ABSOLUTE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_LATE_HALF_DOMINANCE_TRANSLATION_RISK`. One bounded child
  source ID preserves named peer-reviewed DOI and official-exchange lineage
  and discloses the untested late-half dominance gate.
- R2: `PASS`. Synchronized month labels, endpoints, split, return orientation,
  strict magnitude and zero rules, sides, attempt, risk, stops, atomicity,
  spread gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs. Q02 owns history, holiday attrition, costs, financing,
  density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms, indexing,
  arithmetic, comparisons, ATR, quotes, positions, deals, and persistent
  terminal state; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Claim And Kill Boundary

The sources support testing a state-dependent gold/silver relative-value
carrier, not this monthly half-dominance rule's profitability. Expected cadence
is approximately five to eight completed packages per full post-warm-up year.
Q02 must retire below five completed packages per full year, at zero trades,
or with nonpositive governed economics. No failure may be rescued by moving
the split, accepting equality, changing session bounds, adding sign or endpoint
agreement, changing side or hold, or adding a fitted center, volatility,
volume, event, calendar, external, or prior-result state.

Opposite equal-notional legs are designed to reduce common outright-metal
direction but do not prove neutrality or low portfolio correlation. Q09 alone
owns the realized portfolio finding.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
