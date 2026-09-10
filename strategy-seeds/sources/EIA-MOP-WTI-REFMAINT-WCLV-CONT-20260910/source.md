---
source_id: EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910
title: WTI refinery-maintenance weekly lower-tercile continuation
publisher: QuantMechanica governed synthesis of EIA and Moskowitz-Ooi-Pedersen
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_refinery_maintenance_weekly_close_location_continuation_source_approval.md
parent_source_ids: [EIA-WTI-REFINERY-MAINT-2026, MOP-WTI-WCLOSE-LOCATION-MOM-2026]
parent_sha256:
  EIA-WTI-REFINERY-MAINT-2026: 4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097
  MOP-WTI-WCLOSE-LOCATION-MOM-2026: 60292F608787EEC685AAF7B375D66B5A819E21EF2711FA2970AE73945B70F25D
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-refmaint-wclv-cont]
---

# WTI Refinery-Maintenance Weekly Lower-Tercile Continuation

## Complete-Read Record

Both governed parents named above were read end to end before the durable
approval at
`decisions/2026-09-10_wti_refinery_maintenance_weekly_close_location_continuation_source_approval.md`.
The official EIA packet records refinery maintenance/outage structure in late
winter and fall. The momentum packet preserves the complete-paper receipt for
Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, explicit WTI membership, and the disclosed
weekly close-location translation.

## Claim And Translation Boundary

EIA supplies only refinery-maintenance calendar context. The MOP lineage
supplies broad own-return continuation evidence at materially longer horizons.
Neither source tests February/March/September/October, two completed broker
weeks, parent-close return, a lower-tercile close, short-only direction, a
one-week hold, or a Darwinex continuous WTI CFD. The exact rule is a transparent
pre-result QM translation. No performance or diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor attempt before every fallible gate.
2. Require the anchor month to be February, March, September, or October.
3. Reconstruct exactly the newest and parent completed adjacent broker weeks,
   with three through five valid, unique, ordered D1 sessions per week.
4. Compute the strict parent-close return
   `r = ln(newest_final_close / parent_final_close)`.
5. Compute the newest completed week's range location
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
6. When `r < 0` and `clv < 1/3`, sell. Equality, a nonnegative return, a higher
   close location, zero range, malformed or stale packages, or nonfinite
   arithmetic consumes the week flat. No long branch exists.
7. Close at the next normalized week; ten elapsed days is stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and four fuzzy
family members. `QM5_41421` reads only the newest completed week's open-to-
close sign and has no range-location gate; this rule uses two completed weeks,
parent-close to newest-close return, and lower-tercile confirmation. Opening
gaps can make those return signs disagree. `QM5_41426` uses this broader
endpoint/range family only in April-July, requires positive/upper-tercile
states, and buys. `QM5_41080` is year-round, symmetric, and outer-fifth;
`QM5_41081` trades XNG. Calendar, endpoint, lower-tercile gate, short-only side,
and next-week lifecycle are jointly load-bearing.

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

- R1 `PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK`: one canonical
  child packet, with complete official and peer-reviewed parent evidence and
  explicit untested-conjunction risk.
- R2 `PASS`: calendar, packages, endpoints, return, close-location threshold,
  short side, attempt, risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
