---
source_id: EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911
title: WTI refinery-maintenance weekly upper-tercile reversion
publisher: QuantMechanica governed synthesis of EIA and Yang-Goncu-Pantelous
source_type: official_government_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-11_wti_refinery_maintenance_weekly_close_location_reversion_source_approval.md
parent_source_ids: [EIA-WTI-REFINERY-MAINT-2026, YANG-COMM-REVERSAL-2017]
parent_sha256:
  EIA-WTI-REFINERY-MAINT-2026: 4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
created: 2026-09-11
created_by: Research+Development
cards_extracted: [wti-refmaint-wclv-fade]
---

# WTI Refinery-Maintenance Weekly Upper-Tercile Reversion

## Complete-Read Record

Both governed parents named above were read end to end before the durable
approval at
`decisions/2026-09-11_wti_refinery_maintenance_weekly_close_location_reversion_source_approval.md`.
The official EIA packet records recurring refinery maintenance/turnaround
structure. The Yang-Goncu-Pantelous packet preserves academic commodity-
futures reversal lineage.

## Claim And Translation Boundary

EIA supplies only refinery-maintenance context. Yang, Goncu, and Pantelous
supply broad commodity-reversal evidence at other fixed horizons. Neither
source tests February/March/September/October, two completed broker weeks, a
parent-close return, an upper-tercile close, short-only direction, a one-week
hold, or a Darwinex continuous WTI CFD. The exact rule is a transparent pre-
result QM translation. No performance or diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor attempt before every fallible gate.
2. Require the anchor month to be February, March, September, or October.
3. Reconstruct exactly the newest and parent completed adjacent broker weeks,
   with three through five valid, unique, ordered D1 sessions per week.
4. Compute `r = ln(newest_final_close / parent_final_close)`.
5. Compute `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
6. When `r > 0` and `clv > 2/3`, sell. Equality, a nonpositive return, a lower
   close location, zero range, malformed or stale packages, or nonfinite
   arithmetic consumes the week flat. No long branch exists.
7. Close at the next normalized week; ten elapsed days is stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and three fuzzy
family members. `QM5_41427` sells negative/lower-tercile continuation, a
mutually exclusive state. `QM5_41424` uses one week open-to-close without a
range-location gate; gaps can make its endpoint sign disagree. `QM5_41428`
trades April-July and buys negative/lower-tercile reversion. This exact
season/sign/location/direction conjunction is absent.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC/timestamps, broker calendar, quotes,
spread, ATR, symbol metadata, positions, deals, and terminal-global attempt
state only. It does not read EIA data, utilization, outages, futures curves,
volume, files, APIs, portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed or
nonadjacent weekly packages, wrong endpoints, a nonqualifying entry, any long,
retry, missing stop, wrong rollover, nonpositive governed economics, or
nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK`: complete official
  and academic parent evidence, with explicit untested-conjunction risk.
- R2 `PASS`: all signal, lifecycle, and risk rules are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 data.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
