---
source_id: EIA-MOP-WTI-REFMAINT-NEGWEEK-CONT-20260910
title: WTI refinery-maintenance negative-week continuation
publisher: QuantMechanica governed synthesis of EIA and Moskowitz-Ooi-Pedersen
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_refinery_maintenance_negative_week_continuation_source_approval.md
parent_source_ids: [EIA-WTI-REFINERY-MAINT-2026, MOP-TSMOM-2012]
parent_sha256:
  EIA-WTI-REFINERY-MAINT-2026: 4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-refmaint-negweek-cont]
---

# WTI Refinery-Maintenance Negative-Week Continuation

## Complete-Read Record

The two bounded parents above were read end to end before the durable approval
at
`decisions/2026-09-10_wti_refinery_maintenance_negative_week_continuation_source_approval.md`.
The official EIA pages linked by the refinery-maintenance packet were opened
and read on 2026-09-10. EIA's refinery-outage study states that outages are
most frequent in the first quarter and fall, when petroleum-product and crude
demand are seasonally lowest. Its March 2024 analysis states that planned
maintenance generally peaks during late February and March. The MOP packet
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Journal of
Financial Economics*, DOI `10.1016/j.jfineco.2011.11.003`, including
own-return persistence in commodity futures and explicit WTI membership.

## Claim And Translation Boundary

EIA supplies only the February-March and September-October maintenance-regime
context. MOP supplies broad commodity own-return continuation evidence. Neither
source tests one negative completed week, a short-only branch, the one-week
horizon, the cross-source conjunction, or a continuous WTI CFD. The exact
strategy is a transparent pre-result QM translation. No performance or
diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Require the Monday anchor month to be February, March, September, or
   October.
2. Reconstruct exactly the immediately completed normalized broker week with
   three through five valid, unique, ordered D1 sessions.
3. Compute `r = ln(final_close / first_open)`.
4. When `r < 0`, sell. Positive, exact zero, malformed, stale, or nonfinite
   history stays flat. No long branch exists.
5. Persist one attempt before fallible gates and never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan returned `CLEAN`. `QM5_12593` fades a
two-sided D1 stretch-rejection bar in refinery shoulder months. `QM5_12763`
and `QM5_12869` trade May-July squeeze breakout and measured pullback states.
`QM5_41375` is unconditional year-round one-week momentum. `QM5_41419`
requires two negative weeks and is year-round; `QM5_41404` and `QM5_41406`
require two-week agreement in broad winter or summer regimes and are
symmetric. This identity requires the four maintenance months, one immediately
completed negative week, short-only continuation, fixed-risk stop, and
one-week lifecycle together.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC, broker calendar, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state only. It
does not read EIA data, refinery utilization, outages, futures curves, volume,
files, APIs, portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, nonnegative entry, a long trade, retry, missing stop, wrong rollover,
nonpositive governed economics, or nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official EIA
  maintenance-season context and completely read peer-reviewed commodity
  persistence lineage; the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, negative sign, short direction, attempt,
  risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned indicator,
  grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
