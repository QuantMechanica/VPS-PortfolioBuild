---
source_id: EIA-MOP-WTI-HURR-POSWEEK-CONT-20260911
title: WTI hurricane-season positive-week continuation
publisher: QuantMechanica governed synthesis of EIA and Moskowitz-Ooi-Pedersen
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-11_wti_hurricane_positive_week_continuation_source_approval.md
parent_source_ids: [EIA-WTI-HURRICANE-2025, MOP-TSMOM-2012]
parent_sha256:
  EIA-WTI-HURRICANE-2025: F45086ADE9D8D16DE96962783077680DD3B3ACB228E01EBF81F909FAEFF23A8E
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-11
created_by: Research+Development
cards_extracted: [wti-hurr-posweek-cont]
---

# WTI Hurricane-Season Positive-Week Continuation

## Complete-Read Record

Both governed parents named above were read end to end before the durable
approval at
`decisions/2026-09-11_wti_hurricane_positive_week_continuation_source_approval.md`.
The official EIA packet records Atlantic hurricane-season timing and Gulf
Coast petroleum-supply exposure. The peer-reviewed MOP packet records the
complete-paper review, durable PDF hash, WTI membership, and own-return
momentum methodology.

## Claim And Translation Boundary

EIA supplies only hurricane-season physical-risk context. Moskowitz, Ooi, and
Pedersen supply broad futures time-series-momentum evidence that includes WTI.
Neither source tests August-October broker labels, one completed broker week,
long-only selection, a one-week hold, or a Darwinex continuous WTI CFD. The
exact rule is a transparent pre-result QM translation. No performance or
diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor attempt before every fallible gate.
2. Require the anchor month to be August, September, or October.
3. Reconstruct exactly the immediately completed broker week with three
   through five valid, unique, ordered D1 sessions.
4. Compute `r = ln(final_close / first_open)`.
5. When `r > 0`, buy. Equality, nonpositive return, malformed history, stale
   entry, or nonfinite arithmetic consumes the week flat. No short branch
   exists.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity. `QM5_41422` uses
the same sign/direction package only in the disjoint April-May refinery-
restart calendar. `QM5_41421` sells negative weeks in a maintenance calendar,
and `QM5_41424` sells positive weeks as reversion. `QM5_12591` uses a daily
Donchian breakout with trend confirmation; `QM5_12754` fades a daily failed
spike. Natural-gas shoulder-week rules use a different carrier and regime.

The manual verdict is
`CLEAN_WTI_HURRICANE_SEASON_POSITIVE_WEEK_LONG_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC/timestamps, broker calendar, quotes,
spread, ATR, symbol metadata, positions, deals, and terminal-global attempt
state only. It does not read hurricane forecasts, weather, EIA data, refinery
data, futures curves, volume, files, APIs, portfolio state, optimizer output,
or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong calendar eligibility, malformed weekly
packages, nonpositive-week entry, any short, retry, missing stop, wrong
rollover, nonpositive governed economics, or nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK`: complete official
  and peer-reviewed parent evidence, with explicit untested-conjunction risk.
- R2 `PASS`: all signal, lifecycle, and risk rules are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 data.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
