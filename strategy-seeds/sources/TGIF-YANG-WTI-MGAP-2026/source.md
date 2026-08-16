---
source_id: TGIF-YANG-WTI-MGAP-2026
title: WTI first-month-session boundary-gap fade
publisher: Journal of Finance Issues / SSRN
source_type: academic_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_wti_month_boundary_gap_fade_source_approval.md
approval_commit: PENDING
strategy_ids:
  - TGIF-YANG-WTI-MGAP-2026_S01
parent_sources:
  - TGIF-WTI-WEEKEND-2017
  - YANG-COMM-REVERSAL-2017
---

# WTI Month-Boundary Gap Fade Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed academic source lineages whose
repository extractions were read completely before card drafting:

1. Hoelscher, Mbanga, and Nelson (2017), "TGIF? The Weekend Effect in Energy
   Commodities," *Journal of Finance Issues* 16(1), 47-68, DOI
   `10.58886/jfi.v16i1.2264`. The complete official-paper evidence at
   `strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md` supplies explicit
   WTI weekday/weekend return structure and identifies the non-trading gap
   embedded in a close-to-close Monday observation.
2. Liu Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. The governed extraction at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` supplies the
   fixed-horizon commodity-reversal lineage.

The first lineage does not test first-of-month gaps, and the second does not
prescribe close-to-open endpoints. Neither source tests the conjunction, a
Darwinex continuous CFD, normalized broker labels, fixed cash risk, or an ATR
stop. No source performance, significance, cost, drawdown, WTI-only efficacy,
CFD equivalence, correlation, or portfolio result transfers.

## Bounded Mechanization

`TGIF-YANG-WTI-MGAP-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day
  energy convention and require normalized current date to equal broker date;
- decide only on the first genuine normalized D1 session of each broker
  month, within 180 minutes of executable D1 open, with no holiday shift;
- persist the broker-month attempt before every fallible gate;
- require the immediately completed D1 bar to belong to the exactly preceding
  broker month;
- compute `gap_return = log(CurrentOpen / PriorClose)` from the fixed current
  D1 open and prior completed D1 close only;
- BUY after a strictly negative gap and SELL after a strictly positive gap;
  exact zero or invalid history consumes the month flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- close on the first following normalized D1 boundary, with a four-calendar-
  day stale guard and framework Friday-close fail-safe; and
- use no external runtime data, gap threshold, magnitude scaling, retry,
  scale-in, grid, martingale, or pyramid.

The first-session selector, cross-boundary endpoint convention, 180-minute
attachment boundary, risk, stop, spread, and lifecycle are disclosed QM
choices. The sources do not test this interaction or one-D1 hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named academic sources,
  durable complete repository reviews, explicit WTI/commodity relevance, and
  one bounded lineage ID. The working-paper status, untested conjunction,
  source-to-implementation distance, and multiple-testing risk are explicit.
- R2 `PASS`: exact first-session identity, normalized labels, completed
  prior-close/current-open endpoints, contrarian mapping, direction, attempt
  state, entry timing, risk, stop, spread, and exit are deterministic and
  locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history and MT5 execution state supply
  every runtime input. The direct WTI D1 session offset is measured in
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,515 EA-registry rows and 611 root
cards. It found no exact or fuzzy identity. Manual family review returned
`CLEAN_WTI_FIRST_MONTH_SESSION_BOUNDARY_GAP_FADE_AFTER_FAMILY_REVIEW`:

- `QM5_12750` and `QM5_12779` are one-sided, thresholded, target-to-prior-
  close Friday/Monday gap trades; this packet is symmetric, threshold-free,
  target-free, and keyed to the first genuine session of every broker month.
- `QM5_20217` and `QM5_20230` follow prior-range breakaway gaps after
  volatility and optional season gates; this packet fades only the signed
  prior-close/current-open gap.
- `QM5_41027_wti-mopen-rev1` fades the completed first session during the
  second session; this packet fades the cross-month boundary gap during the
  first session.
- `QM5_41016_wti-mclose-mom` follows a five-interval prior-month formation for
  five current-month sessions; this packet has one cross-boundary observation
  and one-session ownership.
- `QM5_12567_cum-rsi2-commodity` is an oscillator pullback across commodity
  carriers, not a WTI month-boundary gap strategy.

The cross-month prior-close/current-open endpoints, first-session clock,
contrarian mapping, and next-D1 lifecycle are the auditable identity. A failed
result may not be rescued by adding a threshold, moving the clock, changing
direction, substituting weekends, adding a target, or extending the hold.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-16_wti_month_boundary_gap_fade_source_approval.md`
authorizes exactly one card, deterministic ID allocation, one branch-only
non-live build, strict Q01, one `RISK_FIXED` backtest setfile, and one paced
Q02 enqueue.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
month/session identity or gap endpoints, current-tick leakage, late or
repeated entry, wrong direction, wrong lifecycle, nondeterminism, invalid risk
mode, or nonpositive governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
