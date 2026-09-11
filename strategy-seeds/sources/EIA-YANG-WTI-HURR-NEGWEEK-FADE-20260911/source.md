---
source_id: EIA-YANG-WTI-HURR-NEGWEEK-FADE-20260911
title: WTI hurricane-season negative-week reversion
publisher: QuantMechanica governed synthesis of EIA and Yang-Goncu-Pantelous
source_type: official_government_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-11_wti_hurricane_negative_week_reversion_source_approval.md
parent_source_ids: [EIA-WTI-HURRICANE-2025, YANG-COMM-REVERSAL-2017]
parent_sha256:
  EIA-WTI-HURRICANE-2025: F45086ADE9D8D16DE96962783077680DD3B3ACB228E01EBF81F909FAEFF23A8E
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
created: 2026-09-11
created_by: Research+Development
cards_extracted: [wti-hurr-negweek-fade]
---

# WTI Hurricane-Season Negative-Week Reversion

## Complete-Read Record

The two bounded parents above were read end to end before extraction, after
the durable approval at
`decisions/2026-09-11_wti_hurricane_negative_week_reversion_source_approval.md`.
The EIA packet preserves official hurricane-season timing and Gulf Coast
petroleum-supply risk. The Yang-Goncu-Pantelous packet preserves academic
commodity-futures reversal lineage and its runtime/data boundary.

## Claim And Translation Boundary

EIA supplies only the hurricane-season physical-risk context. Yang, Goncu,
and Pantelous supply broad commodity-reversal lineage. Neither source tests
August-October Monday anchors, one negative completed WTI week, a long-only
branch, a one-week horizon, the cross-source conjunction, or a continuous WTI
CFD. The exact strategy is a transparent pre-result QM translation. No
performance, density, continuous-CFD equivalence, or diversification claim
transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor week attempt before every fallible gate.
2. Continue only when the anchor month is August, September, or October.
3. Reconstruct exactly the immediately completed normalized broker week with
   three through five valid, unique, ordered D1 sessions.
4. Compute `r = ln(final_close / first_open)` from that completed week only.
5. When `r < 0`, buy. Positive, exact zero, malformed, stale, or nonfinite
   history stays flat. No short branch exists.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and five fuzzy
neighbors. `QM5_41430` uses the same hurricane calendar and long side but
requires a strictly positive completed week as continuation; this rule
requires a strictly negative week as reversion, so their admitted sign states
are mutually exclusive. `QM5_41425` uses the same negative-week/long package
only in April-May refinery-restart months. Maintenance-season siblings use a
different calendar and/or side; `QM5_41392` trades XNG symmetrically. Existing
hurricane EAs use daily breakout or failed-spike states, not this normalized
completed-week sign and one-week lifecycle.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC/timestamps, broker calendar, quotes,
spread, ATR, symbol metadata, positions, deals, and terminal-global attempt
state only. It does not read EIA data, hurricane or weather feeds, refinery
data, futures curves, volume, files, APIs, portfolio state, optimizer output,
or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, nonnegative entry state, a short trade, retry, missing stop, wrong
rollover, nonpositive governed economics, or nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_SHORT_HORIZON_TRANSLATION_RISK`: official EIA
  hurricane context and completely read academic commodity-reversal lineage;
  the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, negative sign, long direction, attempt,
  risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned indicator,
  grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.

