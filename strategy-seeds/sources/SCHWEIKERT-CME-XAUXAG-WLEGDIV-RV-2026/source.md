---
source_id: SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026
title: XAU/XAG completed-week leg-sign divergence reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_xauxag_weekly_leg_divergence_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - xauxag-wlegdiv-rv
---

# XAU/XAG Completed-Week Leg-Sign Divergence Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed parents, both read completely before the durable approval was
written:

- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` preserves
  Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance*
  88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus supporting
  fractional-cointegration lineage.
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records CME Group's
  gold/silver ratio definition, intermarket spread treatment, and the metals'
  differing monetary and industrial drivers.

The durable OWNER approval is
`decisions/2026-08-21_xauxag_weekly_leg_divergence_reversion_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior may be state dependent rather than governed by one constant
cointegrating vector. CME supports expressing gold versus silver as one
intermarket relative-value carrier and explains why the legs can temporarily
diverge because their economic sensitivities differ.

The sources do not establish that opposite signed individual weekly returns
predict a reversal. They do not specify a weekly horizon, a one-week hold,
equal-notional sizing, Darwinex continuous CFDs, fixed cash risk, ATR stops,
spread caps, persistent attempt state, or portfolio behavior. Those are
transparent QM hypotheses. No source alpha, Sharpe ratio, drawdown, density,
hedge ratio, neutrality, cost, CFD equivalence, or portfolio-correlation result
is imported.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of a new Monday-anchored broker week,
reconstruct synchronized week-end close pairs for the two immediately
preceding consecutive broker weeks. For older and newer positive finite close
pairs, define the individual completed-week log returns:

```text
r_gold   = ln(XAU_newer / XAU_older)
r_silver = ln(XAG_newer / XAG_older)
```

Require `r_gold` and `r_silver` to be strictly nonzero and have opposite signs.
Fade the relative winner for one broker week:

```text
r_gold > 0 and r_silver < 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

r_gold < 0 and r_silver > 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

The signal compares the individual legs, not a thresholded ratio return. The
opposite-sign condition guarantees an unambiguous weekly winner and loser.
Magnitude never changes eligibility, direction, or risk. Equality, a zero
return, same-sign returns, asynchronous endpoints, or incomplete weeks are
flat. The current decision-week open, high, low, or close never enters the
signal.

## Exact Event Contract

1. Derive the current broker Monday anchor from the raw host D1 bar time and
   require entry within 180 elapsed minutes of that bar's open.
2. Find exactly one synchronized last D1 close pair in each of the two prior
   consecutive Monday-anchored broker weeks. Each pair must share an exact
   timestamp and be the latest synchronized close in its week.
3. Require positive finite endpoint prices, strict chronological order, no
   current-week endpoint, and strictly opposite nonzero individual log-return
   signs.
4. Persist the current week anchor before history, signal, spread, quote, ATR,
   sizing, news, or order gates. No retry is allowed in that week.
5. Trade one equal-absolute-notional opposite-leg package with aggregate
   `RISK_FIXED=1000`, frozen `3.5 * ATR(20,D1)` per-leg stops, and no target.
6. Close both legs on the first tick of a later broker week, with a ten-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The deterministic checker returned `CLEAN` across 4,570 registry rows and 625
root cards. The nearest gold/silver systems do not share the complete identity:

- rolling ratio/residual cards estimate a center, dispersion, regression, or
  tail; this extraction estimates none;
- `QM5_41030` and `QM5_41040` compare session and overnight relative flows;
  this extraction uses only each metal's full-week endpoint return;
- `QM5_41031` is a thresholded asymmetric daily gold-lead event; this
  extraction is symmetric, weekly, and threshold-free;
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify sequences of the
  gold-minus-silver relative return across weeks; this extraction instead
  requires the two individual metal returns across one common week to have
  opposite signs; and
- `QM5_41079` ranks daily ratio closes inside one week; this extraction has no
  within-week rank and uses only two synchronized week-end pairs.

The exact paired carrier, common weekly interval, strict individual leg-sign
opposition, contrarian relative-winner side, consumed weekly attempt, equal-
notional aggregate-risk package, and next-week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_LEG_STATE_TRANSLATION_RISK`. One bounded child source
  ID preserves named peer-reviewed DOI and official-exchange lineage and
  discloses the untested weekly condition.
- R2: `PASS`. Exact endpoints, sign orientation, sides, attempt, risk, stops,
  atomicity, spread gates, and lifecycle are mechanical and fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms,
  comparisons, ATR, quotes, positions, deals, and persistent terminal state;
  no trained logic, banned signal, external feed, grid, martingale, scale-in,
  or pyramid exists.

## Claim And Kill Boundary

The source supports testing a state-dependent gold/silver relative-value
carrier, not this weekly leg-sign rule's profitability. Expected cadence is
approximately eight to eighteen completed packages per full post-warm-up year.
Q02 must retire below five completed packages per full year, at zero trades or
nonpositive governed economics. No failure may be rescued by accepting zero or
same-sign leg returns, adding a magnitude threshold, changing the side or hold,
or adding a fitted center, volatility, volume, calendar, or external state.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
