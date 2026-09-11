---
source_id: EIA-YANG-WTI-HURR-POSWEEK-FADE-20260911
title: WTI hurricane-season positive-week reversion
publisher: QuantMechanica governed synthesis of EIA and Yang-Goncu-Pantelous
source_type: official_government_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-11_wti_hurricane_positive_week_reversion_source_approval.md
parent_source_ids: [EIA-WTI-HURRICANE-2025, YANG-COMM-REVERSAL-2017]
parent_sha256:
  EIA-WTI-HURRICANE-2025: F45086ADE9D8D16DE96962783077680DD3B3ACB228E01EBF81F909FAEFF23A8E
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
created: 2026-09-11
created_by: Research+Development
cards_extracted: [wti-hurr-posweek-fade]
---

# WTI Hurricane-Season Positive-Week Reversion

## Complete-Read Record

Both governed parents named above were read end to end before the durable
approval at
`decisions/2026-09-11_wti_hurricane_positive_week_reversion_source_approval.md`.
The official EIA packet records Atlantic hurricane-season timing and Gulf
Coast petroleum-supply exposure. The academic Yang-Goncu-Pantelous packet
records commodity-futures reversal lineage and its runtime/data boundary.

## Claim And Translation Boundary

EIA supplies only hurricane-season physical-risk context. Yang, Goncu, and
Pantelous supply broad commodity-reversal lineage. Neither source tests
August-October broker labels, one positive completed WTI week, a short-only
branch, a one-week horizon, the cross-source conjunction, or a continuous WTI
CFD. The exact rule is a transparent pre-result QM translation. No performance,
density, continuous-CFD equivalence, causal attribution, or diversification
claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized broker week:

1. Persist the Monday-anchor attempt before every fallible gate.
2. Require the anchor month to be August, September, or October.
3. Reconstruct exactly the immediately completed broker week with three
   through five valid, unique, ordered D1 sessions.
4. Compute `r = ln(final_close / first_open)`.
5. When `r > 0`, sell. Equality, nonpositive return, malformed history, stale
   entry, or nonfinite arithmetic consumes the week flat. No long branch
   exists.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and six fuzzy
results. `QM5_41430` uses the same positive week and hurricane calendar but
buys continuation. `QM5_41431` buys only after a negative week as reversion,
and `QM5_41432` sells only after a negative week as continuation. `QM5_41424`
has the same positive-week/short package only in the refinery-maintenance
calendar of February, March, September, and October. `QM5_41421` differs in
sign, calendar, and continuation premise. The positive-week, short-only,
August-October conjunction is therefore not already built.

The manual verdict is
`CLEAN_WTI_HURRICANE_SEASON_POSITIVE_WEEK_SHORT_REVERSION_AFTER_FAMILY_REVIEW`.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC/timestamps, broker calendar, quotes,
spread, ATR, symbol metadata, positions, deals, and terminal-global attempt
state only. It does not read hurricane forecasts, weather, EIA data, refinery
data, futures curves, volume, files, APIs, portfolio state, optimizer output,
or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong calendar eligibility, malformed weekly
packages, nonpositive-week entry, any long, retry, missing stop, wrong
rollover, nonpositive governed economics, or nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_SHORT_HORIZON_TRANSLATION_RISK`: complete
  official and academic parent evidence, with explicit untested-conjunction
  risk.
- R2 `PASS`: all signal, lifecycle, and risk rules are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 data.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
