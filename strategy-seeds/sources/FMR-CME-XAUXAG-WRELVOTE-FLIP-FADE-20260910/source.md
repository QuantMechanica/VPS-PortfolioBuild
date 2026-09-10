---
source_id: FMR-CME-XAUXAG-WRELVOTE-FLIP-FADE-20260910
title: XAU/XAG overlapping three-week relative-majority flip reversion
publisher: QuantMechanica governed extraction from peer-reviewed commodity research and official exchange carrier records
source_type: academic_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_xauxag_weekly_relative_vote_flip_reversion_source_approval.md
parent_source_ids: [FMR-MOMTS-2010, CME-GSR-SPREAD-2025, YANG-COMM-REVERSAL-2017]
created: 2026-09-10
created_by: Research+Development
cards_extracted: [xauxag-wrelvote-flip-fade]
---

# XAU/XAG Overlapping Three-Week Relative-Majority Flip Reversion

## Complete-Read Record

The bounded parent records `strategy-seeds/sources/FMR-MOMTS-2010/source.md`,
`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, and
`strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` were read end to end
before this extraction. The first preserves the complete 47-page accepted
manuscript and DOI for Fuertes, Miffre, and Rallis (2010), *Tactical
Allocation in Commodity Futures Markets: Combining Momentum and Term Structure
Signals*, *Journal of Banking & Finance* 34(10), 2530–2548. It defines
cross-sectional commodity momentum. The second preserves CME's definition of
the gold/silver ratio and the gold/silver intermarket-spread carrier. The third
supplies named academic commodity-reversal lineage through Yang, Goncu, and
Pantelous (2017), SSRN 3069253.

Neither parent tests overlapping three-week sign votes, a majority flip,
fading the new majority, Monday-anchored continuous-CFD labels, equal-notional
sizing, fixed cash risk, or ATR stops. Those are transparent QuantMechanica
translations. No reported return, significance, cause, neutrality, or
portfolio-decorrelation claim transfers.

## Bounded Mechanization

At the first tradable `XAUUSD.DWX` D1 bar of each new broker week:

1. Reconstruct the final synchronized XAU/XAG closes of exactly the five
   immediately completed adjacent Monday-anchored broker weeks, each with
   three through five unique valid synchronized D1 sessions.
2. In chronological order compute four adjacent relative returns
   `d[i] = ln(XAU[i+1]/XAU[i]) - ln(XAG[i+1]/XAG[i])`.
3. Require every `d[i]` finite and strict nonzero beyond `1e-10`.
4. Compare sign majorities in `d0,d1,d2` and `d1,d2,d3`; require them to
   oppose exactly.
5. Fade the newer relative majority: sell XAU/buy XAG when it is positive;
   buy XAU/sell XAG when it is negative.
6. Persist one weekly attempt before history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
7. Close both legs at the next broker week; ten elapsed days is stale repair.
8. Use one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, independent
   frozen `3.5*ATR(20,D1)` hard stops, equal absolute notional within 20%, no
   target, and XAU/XAG spread ceilings of 1,500/500 points.

## Non-Duplicate Boundary

The pre-allocation checker found no exact identity. `QM5_41414` owns the same
overlap-and-vote state but follows the new majority; this extraction fades it.
That direction is the complete economic hypothesis. `QM5_41372` uses the
economically different XTI/XNG carrier. `QM5_41413` reads four endpoints and
requires exact alternation, rather than two overlapping majority windows over
five endpoints. Monthly XAU/XAG votes use different clocks and return objects.
Verdict: `DISTINCT_XAUXAG_OVERLAPPING_THREE_WEEK_RELATIVE_MAJORITY_FLIP_REVERSION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_DIRECTION_HORIZON_AND_STATE_TRANSLATION_RISK`: peer-reviewed
  commodity-momentum research, named academic commodity-reversal work, and
  official-exchange carrier lineage; the exact weekly fade is untested.
- R2 `PASS`: endpoints, votes, side, attempt, risk, stops, notional tolerance,
  spreads, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories supply every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no trained component,
  banned signal, external feed, or adaptive PnL fit.

## Runtime And Falsification Boundary

Runtime uses only input-bound XAU/XAG D1 bars, broker time, quotes, spread,
ATR, symbol metadata, positions, deals, and terminal-global attempt state.
Retire rather than tune on zero packages, fewer than five completed packages
in any full post-warm-up year, nonpositive governed economics, asynchronous
weeks, wrong vote windows or side, duplicate attempts, orphan exposure,
aggregate-risk breach, missing stop, wrong next-week exit, or nondeterminism.
Q09 alone may establish realized portfolio decorrelation.

## Safety Boundary

This packet supports research, one V5 branch build, strict Q01, and one paced
non-live logical Q02 handoff only. It does not authorize manual backtests,
live artifacts, `T_Live`, AutoTrading, deploy manifests, portfolio-gate
changes, portfolio admission, correlation waivers, or decorrelation claims.
