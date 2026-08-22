---
source_id: SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026
title: XAU/XAG completed-month close-quartile reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_close_quartile_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-mclose-quartile-rv
---

# XAU/XAG Completed-Month Close-Quartile Reversion Source Packet

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
`decisions/2026-08-22_xauxag_monthly_close_quartile_reversion_source_approval.md`,
committed before this extraction at `7649b3e95`. No new online page, blocked
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

The sources do not establish that the final relative close's rank inside one
completed calendar month predicts reversal. They do not specify a 17-to-23-
session calendar month, an inclusive-count quartile, strict tie rejection, a
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
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..n-1
z    = s[n-1]
rank = count(s[i] < z for i=0..n-1)
tail = ceil(n/4) = (n+3)//4

any s[i] == z for i=0..n-2
    => FLAT

rank < tail
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

rank >= n-tail
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

otherwise
    => FLAT
```

The newest close participates once. Under the locked session bound, each
outer set contains five or six possible unique ranks. Equality, an interior
rank, asynchronous history, mixed month labels, invalid prices, incomplete
history, or a current-month observation consumes the month flat. Rank
distance never changes direction, sizing, stops, or lifecycle.

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
4. Reverse the ratios into chronological order, require the newest ratio to
   be unique, compute `rank` by strict lower-count, set `tail=(n+3)//4`, and
   trade only the lower or upper fixed rank set. Every interior rank and tie
   remains flat.
5. Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. No retry is allowed that month.
6. Fade the newest close rank with one equal-absolute-notional opposite-leg
   package. Combined normalized hard-stop risk is capped at aggregate
   `RISK_FIXED=1000`; each leg receives a frozen `3.5 * ATR(20,D1)` stop and
   no target.
7. Close both legs on the first tick of a later broker month, with a forty-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,618 registry identities, 1,287 repository cards, and 45 Strategy-Wiki
nodes. Evidence is
`artifacts/qm5_xauxag_mclose_quartile_rv_preallocation_dedup_20260822.json`.

Manual semantic review finds a new mechanic:

- `QM5_41079_xauxag-wclose-extreme-rv` requires the unique newest minimum or
  maximum inside one three-to-five-session completed week and holds one week.
  This extraction uses fixed outer quartile rank sets inside a 17-to-23-
  session completed calendar month and holds one month.
- `QM5_20268_xauxag-qtail-rv` ranks against a frozen 126-value rolling
  distribution, requires a central-plus-two-tail event, and exits at a
  rolling median. This extraction ranks only the final close inside one month
  and has a fixed next-month exit.
- `QM5_41118_xauxag-mlatehalf-dom-rv` partitions adjacent relative returns
  into two exhaustive blocks and compares cumulative magnitudes. This
  extraction compares close levels and uses no return block.
- `QM5_41110_xauxag-moutside-res-rv` measures residence outside a parent-
  month range. This extraction has neither a parent range nor residence count.
- `QM5_41103_xauxag-mrange-migrate-rv` compares two completed monthly ranges.
  This extraction reconstructs one month and ranks only its final close.
- rolling ratio/residual cards (`QM5_12577`, `QM5_20157`, `QM5_20161`,
  `QM5_20263`, and `QM5_20268`) estimate a center, regression, scale, score,
  or empirical tail; this extraction estimates none.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, chronological ratio closes, strict newest-
close uniqueness, fixed `ceil(n/4)` outer rank sets, contrarian package,
consumed monthly attempt, equal-notional aggregate-risk package, and next-
month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_CLOSE_QUARTILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_CLOSE_QUARTILE_TRANSLATION_RISK`. One bounded child source
  ID preserves named peer-reviewed DOI and official-exchange lineage and
  discloses the untested close-rank gate.
- R2: `PASS`. Synchronized month labels, chronology, strict rank, quartile
  arithmetic, tie rule, sides, attempt, risk, stops, atomicity, spread gates,
  and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs. Q02 owns history, holiday attrition, costs, financing,
  density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms, integer
  ranking, comparisons, ATR, quotes, positions, deals, and persistent
  terminal state; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Claim And Kill Boundary

The sources support testing a state-dependent gold/silver relative-value
carrier, not this close-quartile rule's profitability. Expected cadence is
approximately five to seven completed packages per full post-warm-up year.
Q02 must retire below five completed packages per full year, at zero trades,
or with nonpositive governed economics. No failure may be rescued by changing
the quartile definition, accepting ties, changing session bounds, changing
side or hold, or adding a fitted center, scale, return, volatility, volume,
event, calendar, external, or prior-result state.

Opposite equal-notional legs are designed to reduce common outright-metal
direction but do not prove neutrality or low portfolio correlation. Q09 alone
owns the realized portfolio finding.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
