---
source_id: SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026
title: XAU/XAG completed-week common-shock dispersion reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_xauxag_weekly_common_shock_dispersion_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - xauxag-commonshock-rv
---

# XAU/XAG Completed-Week Common-Shock Dispersion Reversion Source Packet

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
`decisions/2026-08-21_xauxag_weekly_common_shock_dispersion_reversion_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior may be state dependent rather than governed by one constant
cointegrating vector. CME supports expressing gold versus silver as one
intermarket relative-value carrier and explains why the legs can temporarily
diverge because their economic sensitivities differ.

The sources do not establish that same-direction weekly metal returns identify
a common shock or predict relative reversal. They do not specify the weekly
clock, a symmetric outperformer fade, equal-notional sizing, Darwinex
continuous CFDs, fixed cash risk, ATR stops, spread caps, persistent attempt
state, or portfolio behavior. Those are transparent QM hypotheses. No source
alpha, Sharpe ratio, drawdown, density, hedge ratio, neutrality, cost, CFD
equivalence, or portfolio-correlation result is imported.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of a new Monday-anchored broker week,
reconstruct synchronized final close pairs for the immediately completed week
and its consecutive parent week. Each completed week must contain three to
five synchronized sessions. Define each leg's completed weekly log return:

```text
g = ln(XAU_newest_week_final / XAU_parent_week_final)
s = ln(XAG_newest_week_final / XAG_parent_week_final)

g > 0 and s > 0 and g > s  => SELL XAUUSD.DWX, BUY XAGUSD.DWX
g > 0 and s > 0 and g < s  => BUY XAUUSD.DWX, SELL XAGUSD.DWX
g < 0 and s < 0 and g > s  => SELL XAUUSD.DWX, BUY XAGUSD.DWX
g < 0 and s < 0 and g < s  => BUY XAUUSD.DWX, SELL XAGUSD.DWX
otherwise                   => FLAT
```

Thus both metals must share one strict directional state, while the package
fades the strict relative outperformer. Equality, zero, mixed signs, missing
or nonconsecutive endpoints, asynchronous bars, or an invalid completed week
consumes the decision week flat. No current decision-week price enters the
signal, and return magnitude never changes sizing.

## Exact Event Contract

1. Derive the current broker Monday anchor from the raw host D1 bar time and
   require entry within 180 elapsed minutes of that bar's open.
2. Require synchronized current host/companion D1 timestamps and consecutive
   parent/newest completed-week anchors with three to five synchronized
   sessions in each week.
3. Use only the final synchronized close pair from each completed week;
   compute individual weekly log returns, require a strict shared sign, and
   fade the strict relative outperformer.
4. Persist the current week anchor before history, signal, spread, quote, ATR,
   sizing, news, or order gates. No retry is allowed in that week.
5. Trade one equal-absolute-notional opposite-leg package with aggregate
   `RISK_FIXED=1000`, frozen `3.5 * ATR(20,D1)` per-leg stops, and no target.
6. Close both legs on the first tick of a later broker week, with a ten-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The deterministic checker returned `CLEAN` across 4,573 registry rows and 625
root cards. The nearest gold/silver systems do not share the complete identity:

- `QM5_41031_xauxag-goldlead` requires a one-D1 gold-only shock of at least 75
  basis points and a bounded silver response below one-half of gold's move;
  it is asymmetric, never allows silver leadership, and exits next D1. This
  extraction is symmetric, weekly, threshold-free, and requires both legs to
  share a strict sign.
- `QM5_41083_xauxag-wlegdiv-rv` requires opposite-sign individual completed-
  week returns. This extraction requires same-sign returns, so their admitted
  state spaces are disjoint.
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify two or more weekly
  gold-minus-silver returns by magnitude or path. This extraction uses one
  return per individual metal and no multiweek relative-return state.
- `QM5_41057_xauxag-wflow-agree-fade` decomposes weekly overnight and session
  relative flows. This extraction uses final close endpoints only.
- `QM5_41085_xauxag-wdaybreadth-rv` counts within-week relative-return signs;
  this extraction counts none and does not require exactly five sessions.
- rolling ratio/residual cards estimate a center, regression, scale, score,
  or tail; this extraction estimates none.

The exact paired carrier, consecutive synchronized completed-week endpoints,
strict same-sign individual returns, symmetric relative-outperformer fade,
consumed weekly attempt, equal-notional aggregate-risk package, and next-week
exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_COMMON_SHOCK_TRANSLATION_RISK`. The child source preserves
  named peer-reviewed DOI and official-exchange lineage and discloses the
  untested same-direction weekly fade.
- R2: `PASS`. Exact endpoints, return orientation, zero/equality handling,
  sides, attempt, risk, stops, atomicity, spread gates, and lifecycle are
  mechanical and fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms,
  comparisons, ATR, quotes, positions, deals, and persistent terminal state;
  no trained logic, banned signal, external feed, grid, martingale, scale-in,
  or pyramid exists.

## Claim And Kill Boundary

The sources support testing a state-dependent gold/silver relative-value
carrier, not this same-sign weekly rule's profitability. Expected cadence is
approximately fifteen to thirty-five completed packages per full post-warm-up
year. Q02 must retire below five completed packages per full year, at zero
trades or nonpositive governed economics. No failure may be rescued by
accepting mixed signs, adding a magnitude threshold, changing the package
side or hold, or fitting a center, volatility, volume, calendar, or external
state.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
