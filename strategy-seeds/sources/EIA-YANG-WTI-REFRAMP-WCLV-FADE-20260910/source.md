---
source_id: EIA-YANG-WTI-REFRAMP-WCLV-FADE-20260910
title: WTI refinery-ramp weekly lower-tercile reversion
publisher: QuantMechanica governed synthesis of EIA and Yang-Goncu-Pantelous
source_type: official_government_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_refinery_ramp_weekly_close_location_reversion_source_approval.md
parent_source_ids: [EIA-WTI-REFINERY-MAINT-2026, YANG-COMM-REVERSAL-2017]
parent_sha256:
  EIA-WTI-REFINERY-MAINT-2026: 4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-reframp-wclv-fade]
---

# WTI Refinery-Ramp Weekly Lower-Tercile Reversion

## Complete-Read Record

Both governed parents named above were read end to end before the durable
approval at
`decisions/2026-09-10_wti_refinery_ramp_weekly_close_location_reversion_source_approval.md`.
The official EIA packet records refinery maintenance/outage structure and the
transition toward higher utilization heading into summer. The Yang-Goncu-
Pantelous packet preserves academic commodity-futures reversal lineage.

The public URL router classified fresh EIA and SSRN retrieval attempts as
`DEFERRED:SOURCE_POLICY`. No blocked text or inferred page content was used.

## Claim And Translation Boundary

EIA supplies only refinery-maintenance and utilization-ramp context. Yang,
Goncu, and Pantelous supply broad commodity-reversal evidence at other fixed
horizons. Neither source tests April-July, two completed broker weeks, a
parent-close return, a lower-tercile close, long-only direction, a one-week
hold, or a Darwinex continuous WTI CFD. The exact rule is a transparent pre-
result QM translation. No performance or diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor attempt before every fallible gate.
2. Require the anchor month to be April, May, June, or July.
3. Reconstruct exactly the newest and parent completed adjacent broker weeks,
   with three through five valid, unique, ordered D1 sessions per week.
4. Compute the strict parent-close return
   `r = ln(newest_final_close / parent_final_close)`.
5. Compute the newest completed week's range location
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
6. When `r < 0` and `clv < 1/3`, buy. Equality, a nonnegative return, a higher
   close location, zero range, malformed or stale packages, or nonfinite
   arithmetic consumes the week flat. No short branch exists.
7. Close at the next normalized week; ten elapsed days is stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and one fuzzy family
member. `QM5_41426` admits only positive parent-close returns with upper-
tercile closes, also long but as continuation. This rule admits only negative
returns with lower-tercile closes as reversion, so the states are mutually
exclusive. `QM5_41425` is April-May only and uses one completed week's open-
to-close sign without range confirmation; opening gaps can make its endpoint
sign disagree with this rule. Existing daily refinery squeeze/pullback cards
use current D1 patterns rather than frozen completed-week endpoint/range state.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC/timestamps, broker calendar, quotes,
spread, ATR, symbol metadata, positions, deals, and terminal-global attempt
state only. It does not read EIA data, utilization, outages, futures curves,
volume, files, APIs, portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed or
nonadjacent weekly packages, wrong endpoints, a nonqualifying entry, any
short, retry, missing stop, wrong rollover, nonpositive governed economics, or
nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK`: one canonical
  child packet, with complete official and academic parent evidence and
  explicit untested-conjunction risk.
- R2 `PASS`: calendar, packages, endpoints, return, close-location threshold,
  long side, attempt, risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
