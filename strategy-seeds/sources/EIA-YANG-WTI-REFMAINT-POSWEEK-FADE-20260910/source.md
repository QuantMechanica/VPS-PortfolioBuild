---
source_id: EIA-YANG-WTI-REFMAINT-POSWEEK-FADE-20260910
title: WTI refinery-maintenance positive-week reversion
publisher: QuantMechanica governed synthesis of EIA and Yang-Goncu-Pantelous
source_type: official_government_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_refinery_maintenance_positive_week_reversion_source_approval.md
parent_source_ids: [EIA-WTI-REFINERY-MAINT-2026, YANG-COMM-REVERSAL-2017]
parent_sha256:
  EIA-WTI-REFINERY-MAINT-2026: 4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-refmaint-posweek-fade]
---

# WTI Refinery-Maintenance Positive-Week Reversion

## Complete-Read Record

The two bounded parents above were read end to end before extraction, after
the durable approval at
`decisions/2026-09-10_wti_refinery_maintenance_positive_week_reversion_source_approval.md`.
The EIA packet preserves official refinery-outage and maintenance-season
findings. The Yang-Goncu-Pantelous packet preserves academic commodity-
futures reversal lineage and its runtime/data boundary.

## Claim And Translation Boundary

EIA supplies only the February-March and September-October refinery-
maintenance context. Yang, Goncu, and Pantelous supply broad commodity-
reversal lineage. Neither source tests one positive completed WTI week, a
short-only branch, the one-week horizon, the cross-source conjunction, or a
continuous WTI CFD. The exact strategy is a transparent pre-result QM
translation. No performance, density, continuous-CFD equivalence, or
diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor week attempt before every fallible gate.
2. Continue only when the anchor month is February, March, September, or
   October.
3. Reconstruct exactly the immediately completed normalized broker week with
   three through five valid, unique, ordered D1 sessions.
4. Compute `r = ln(final_close / first_open)` from that completed week only.
5. When `r > 0`, sell. Negative, exact zero, malformed, stale, or nonfinite
   history stays flat. No long branch exists.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and two fuzzy
neighbors. `QM5_41421` uses the same WTI maintenance calendar and short side
but requires a strictly negative completed week as continuation. This rule
requires a strictly positive week as reversion, making their admitted sign
states mutually exclusive. `QM5_41392` trades XNG, uses a different month
set, and has symmetric long/short branches. Refiner stretch, squeeze,
pullback, year-round momentum, multiweek streak, and winter/summer agreement
systems use different states, calendars, or lifecycles.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC/timestamps, broker calendar, quotes,
spread, ATR, symbol metadata, positions, deals, and terminal-global attempt
state only. It does not read EIA data, refinery utilization, outages, futures
curves, volume, files, APIs, portfolio state, optimizer output, or trained
artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, nonpositive entry state, a long trade, retry, missing stop, wrong
rollover, nonpositive governed economics, or nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_SHORT_HORIZON_TRANSLATION_RISK`: official EIA
  maintenance-season context and completely read academic commodity-reversal
  lineage; the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, positive sign, short direction, attempt,
  risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned indicator,
  grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
