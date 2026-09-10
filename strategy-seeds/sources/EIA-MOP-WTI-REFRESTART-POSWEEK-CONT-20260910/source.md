---
source_id: EIA-MOP-WTI-REFRESTART-POSWEEK-CONT-20260910
title: WTI refinery-restart positive-week continuation
publisher: QuantMechanica governed synthesis of EIA and Moskowitz-Ooi-Pedersen
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_refinery_restart_positive_week_continuation_source_approval.md
parent_source_ids: [EIA-WTI-REFINERY-MAINT-2026, MOP-TSMOM-2012]
parent_sha256:
  EIA-WTI-REFINERY-MAINT-2026: 4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-refrestart-posweek-cont]
---

# WTI Refinery-Restart Positive-Week Continuation

## Complete-Read Record

The two bounded parents above were read end to end before the durable approval
at
`decisions/2026-09-10_wti_refinery_restart_positive_week_continuation_source_approval.md`.
The EIA packet records official refinery-outage and pre-summer utilization
sources and states that planned maintenance generally peaks in late February
and March. The MOP packet records a complete read of Moskowitz, Ooi, and
Pedersen (2012), *Journal of Financial Economics*, DOI
`10.1016/j.jfineco.2011.11.003`, including own-return persistence in commodity
futures and explicit WTI membership.

## Claim And Translation Boundary

EIA supplies only the transition from late-winter maintenance toward higher
refinery utilization heading into summer. MOP supplies broad commodity
own-return continuation evidence at tested monthly horizons. Neither source
tests April-May, one positive completed week, a long-only branch, the one-week
horizon, the cross-source conjunction, or a continuous WTI CFD. The exact
strategy is a transparent pre-result QM translation. No performance or
diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Require the Monday anchor month to be April or May.
2. Reconstruct exactly the immediately completed normalized broker week with
   three through five valid, unique, ordered D1 sessions.
3. Compute `r = ln(final_close / first_open)`.
4. When `r > 0`, buy. Negative, exact zero, malformed, stale, or nonfinite
   history stays flat. No short branch exists.
5. Persist one attempt before fallible gates and never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and surfaced three
fuzzy family neighbors for manual review. `QM5_41392` and `QM5_41420` trade
XNG rather than WTI and use contrarian or two-week-agreement shoulder logic.
`QM5_41421` trades WTI but only shorts negative weeks during the opposite
maintenance months. `QM5_12763` and `QM5_12869` operate in May-July and need
daily compression/breakout or pullback/rebound states. This identity requires
April-May post-maintenance anchors, one immediately completed positive week,
long-only continuation, fixed-risk stop, and one-week lifecycle together.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC, broker calendar, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state only. It
does not read EIA data, refinery utilization, outages, futures curves, volume,
files, APIs, portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, nonpositive entry, a short trade, retry, missing stop, wrong
rollover, nonpositive governed economics, or nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official EIA
  maintenance/restart context and completely read peer-reviewed commodity
  persistence lineage; the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, positive sign, long direction, attempt,
  risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned indicator,
  grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
