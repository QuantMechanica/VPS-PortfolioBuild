---
source_id: FMR-CME-XAUXAG-WALT3-CONT-20260910
title: XAU/XAG three-week strict relative-sign alternation continuation
publisher: QuantMechanica governed extraction from peer-reviewed commodity-momentum and official exchange carrier records
source_type: academic_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_xauxag_weekly_alternation_continuation_source_approval.md
parent_source_ids: [FMR-MOMTS-2010, CME-GSR-SPREAD-2025]
created: 2026-09-10
created_by: Research+Development
cards_extracted: [xauxag-walt3-cont]
---

# XAU/XAG Three-Week Strict Relative-Sign Alternation Continuation

## Complete-Read Record

The bounded parent records `strategy-seeds/sources/FMR-MOMTS-2010/source.md`
and `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` were read end to end
before this extraction. The first preserves the complete 47-page accepted
manuscript and DOI for Fuertes, Miffre, and Rallis (2010), *Tactical
Allocation in Commodity Futures Markets: Combining Momentum and Term Structure
Signals*, Journal of Banking & Finance 34(10), 2530-2548. It mechanically
defines cross-sectional commodity momentum, including one-month formation and
one-month holding variants. The second preserves CME's definition of the
gold/silver ratio and gold/silver intermarket-spread carrier.

The academic source tests broad futures portfolios rather than a two-metal
weekly CFD package. Neither parent tests strict weekly sign alternation,
Monday-anchored continuous-CFD labels, equal-notional sizing, fixed cash risk,
or ATR stops. Those are transparent QuantMechanica translations. No reported
return, significance, cause, market neutrality, or portfolio decorrelation
claim transfers.

## Bounded Mechanization

At the first tradable `XAUUSD.DWX` D1 bar of each new normalized broker week:

1. Reconstruct the final synchronized XAU/XAG closes of exactly the four
   immediately completed adjacent normalized broker weeks, each with three
   through five unique valid synchronized D1 sessions.
2. In chronological order compute the three adjacent relative returns
   `d[i] = ln(XAU[i+1]/XAU[i]) - ln(XAG[i+1]/XAG[i])`.
3. Require each `d[i]` finite, strict nonzero beyond `1e-10`, and alternating
   `+,-,+` or `-,+,-`.
4. Continue the newest relative sign: buy XAU/sell XAG after `+,-,+`; sell
   XAU/buy XAG after `-,+,-`.
5. Persist one weekly attempt before history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
6. Close both legs at the next normalized week; ten elapsed days is stale
   repair.
7. Use one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, independent
   frozen `3.5*ATR(20,D1)` hard stops, equal absolute notional within 20%, no
   target, and XAU/XAG spread ceilings of 1,500/500 points.

## Non-Duplicate Boundary

The pre-allocation checker found no exact identity. Its two fuzzy matches are
expected and manually resolved. `QM5_41410_xauxag-walt3-rv` trades the same
four synchronized endpoints and strict three-return alternation but takes the
opposite side, fading the newest relative winner. Direction is the complete
economic hypothesis and therefore a load-bearing identity field.
`QM5_41373_xtixng-walt3-rv` uses an energy cross-market carrier and also fades.
`QM5_41078_xauxag-wstreak3-rv` requires a fresh three-week same-sign streak
after an opposite predecessor; it does not admit alternating paths. Monthly
XAU/XAG cross-sectional momentum cards use different clocks and return
objects.

Verdict:
`DISTINCT_XAUXAG_THREE_COMPLETED_RELATIVE_WEEK_ALTERNATION_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_STATE_TRANSLATION_RISK`: one governed source
  packet preserves peer-reviewed commodity-momentum and official-exchange
  carrier lineage; exact weekly alternation efficacy is untested.
- R2 `PASS`: endpoints, signs, continuation side, attempt, aggregate risk,
  stops, notional tolerance, spreads, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories supply every runtime market input.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR, quotes, and position state only;
  no trained component, banned signal, external feed, or adaptive PnL fit.

## Runtime And Falsification Boundary

Runtime uses only input-bound XAU/XAG D1 bars, broker time, quotes, spread,
ATR, symbol metadata, positions, deals, and terminal-global attempt state.
Retire rather than tune on zero packages, fewer than five completed packages
in any full post-warm-up year, nonpositive governed economics, asynchronous
weeks, wrong sign or side, duplicate attempt, orphan exposure, aggregate-risk
breach, missing stop, wrong next-week exit, or nondeterminism. Q09 alone may
establish realized portfolio decorrelation.
