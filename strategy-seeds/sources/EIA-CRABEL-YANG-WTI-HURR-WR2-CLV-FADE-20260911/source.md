---
source_id: EIA-CRABEL-YANG-WTI-HURR-WR2-CLV-FADE-20260911
title: WTI hurricane-season weekly range-expansion close-location reversion
publisher: QuantMechanica governed synthesis of EIA, Crabel lineage, and Yang-Goncu-Pantelous
source_type: official_government_reputable_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-11_wti_hurricane_wr2_clv_reversion_source_approval.md
parent_source_ids: [EIA-WTI-HURRICANE-2025, CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026, YANG-COMM-REVERSAL-2017]
parent_sha256:
  EIA-WTI-HURRICANE-2025: F45086ADE9D8D16DE96962783077680DD3B3ACB228E01EBF81F909FAEFF23A8E
  CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026: CB2CF103AB378C344E4E560B2E44DD9ED9E092A3769450E1A1C20FCF98A53885
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
created: 2026-09-11
created_by: Research+Development
cards_extracted: [wti-hurr-wr2-clv-fade]
---

# WTI Hurricane-Season Weekly Range-Expansion Reversion

## Complete-Read Record

All three governed parent records named above were read end to end before the
durable approval at
`decisions/2026-09-11_wti_hurricane_wr2_clv_reversion_source_approval.md`.
The official EIA record documents Atlantic hurricane-season timing and Gulf
Coast petroleum-supply exposure. The governed Crabel packet preserves
systematic completed-week range-state lineage. The Yang-Goncu-Pantelous packet
preserves academic commodity-futures reversal lineage.

## Claim And Translation Boundary

EIA supplies only hurricane-season physical-risk context. Crabel supplies
range-state lineage, while Yang, Goncu, and Pantelous supply broad commodity-
reversal evidence at other horizons. None tests August-October broker labels,
two completed WTI weeks, strict range expansion, an upper-quartile settlement,
a short-only one-week fade, or the Darwinex continuous WTI CFD. The exact rule
is a transparent pre-result QM translation. No performance, causality,
continuous-CFD equivalence, or diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor attempt before every fallible gate.
2. Require the anchor month to be August, September, or October.
3. Reconstruct exactly the two immediately completed consecutive broker weeks,
   with three through five valid, unique, ordered D1 sessions per week.
4. For each week compute full range `R = high-low`; for the newest week compute
   `CLV = (final_close-low)/R`.
5. Require the newest range to be strictly greater than the prior range and the
   newest `CLV` to be strictly greater than `0.75`.
6. When both predicates pass, sell. Weekly body sign is deliberately ignored.
   Equality, a narrower range, a lower close location, zero range, malformed or
   stale packages, or nonfinite arithmetic consumes the week flat. No long
   branch exists.
7. Close at the next normalized week; ten elapsed days is stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and surfaced seven
fuzzy family results. `QM5_41434` has the identical calendar and WR2/CLV state
but buys continuation, whereas this candidate sells reversion. `QM5_41433`
sells after any strictly positive completed-week return and does not compare
ranges or require close location; a negative-body week can therefore qualify
here but not there. `QM5_12754` uses a single D1 failed-spike bar above SMA with
ATR stretch and mean/window exits, not a frozen completed-week WR2 state.
`QM5_12861` trades another carrier. The remaining hits are duplicate card-store
copies of those families rather than exact mechanics.

The manual verdict is
`CLEAN_WTI_HURRICANE_WR2_UPPER_QUARTILE_SHORT_REVERSION_AFTER_FAMILY_REVIEW`.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC/timestamps, broker calendar, quotes,
spread, ATR, symbol metadata, positions, deals, and terminal-global attempt
state only. It does not read hurricane forecasts, weather, EIA data, refinery
data, futures curves, volume, files, APIs, portfolio state, optimizer output,
or trained artifacts.

Retire rather than tune on zero trades, fewer than three completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed or
nonadjacent weekly packages, a nonexpanding newest range, `CLV<=0.75`, any
long, retry, missing stop, wrong rollover, nonpositive governed economics, or
nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: one canonical
  child packet with completely read official, reputable, and academic parents;
  the untested conjunction is explicit.
- R2 `PASS`: calendar, two packages, strict range and CLV predicates, short
  side, attempt, stop, risk, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
