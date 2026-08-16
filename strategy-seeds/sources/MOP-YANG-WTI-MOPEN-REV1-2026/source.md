---
source_id: MOP-YANG-WTI-MOPEN-REV1-2026
title: WTI second-session reversal of the first broker-month session
publisher: Journal of Financial Economics / SSRN
source_type: academic_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_wti_month_opening_reversal_source_approval.md
approval_commit: 664785e3f
strategy_ids:
  - MOP-YANG-WTI-MOPEN-REV1-2026_S01
parent_sources:
  - MOP-WTI-MOPEN-MOM-2026
  - YANG-COMM-REVERSAL-2017
---

# WTI Month-Opening Session Reversal Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed academic source lineages whose
repository extractions were read completely before card drafting:

1. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The bounded WTI month-opening extraction at
   `strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md` preserves the
   complete-paper evidence, explicit WTI membership, own-return-sign rule, and
   fixed broker-month opening-segment construction.
2. Liu Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. The governed extraction at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` supplies the
   commodity-reversal lineage and documents fixed-horizon reversal
   translations on registered energy carriers.

The first lineage supplies a fixed month-opening information clock and the
second supplies contrarian commodity-return lineage. Neither source tests the
exact first-session/second-session conjunction, a Darwinex continuous CFD,
normalized broker labels, fixed cash risk, or an ATR stop. No source
performance, significance, cost, drawdown, WTI-only efficacy, CFD equivalence,
correlation, or portfolio result transfers.

## Bounded Mechanization

`MOP-YANG-WTI-MOPEN-REV1-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day
  energy convention and require normalized current date to equal broker date;
- decide only on the second genuine normalized D1 session of each broker
  month, within 180 minutes of executable D1 open, with no holiday shift;
- persist the broker-month attempt before every fallible gate;
- require the immediately completed D1 bar to be the first session of the
  current month and its predecessor to belong to the immediately preceding
  month;
- compute the completed first-session return as
  `log(FirstSessionClose / FirstSessionOpen)`;
- BUY after a strictly negative first-session return and SELL after a strictly
  positive return; exact zero or invalid history consumes the month flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- close on the first following normalized D1 boundary, with a four-calendar-
  day stale guard and framework Friday-close fail-safe; and
- use no external runtime data, magnitude scaling, retry, scale-in, grid,
  martingale, or pyramid.

The ordinal session clock, intrabar endpoint convention, 180-minute
attachment boundary, risk, stop, spread, and lifecycle are disclosed QM
choices. The sources do not test this interaction or one-D1 hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named academic sources,
  durable complete repository reviews, explicit commodity/WTI relevance, and
  one bounded lineage ID. The working-paper status, untested conjunction,
  source-to-implementation distance, and multiple-testing risk are explicit.
- R2 `PASS`: exact ordinal sessions, normalized labels, completed first-
  session endpoints, contrarian mapping, direction, attempt state, entry
  timing, risk, stop, spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history and MT5 execution state supply
  every runtime input. The direct WTI D1 session offset is measured in
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR, quote, position,
  deal-history, and framework state only; no trained output, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,514 EA-registry rows and 610 root
cards. It found no exact identity and raised only `wti-mopen-mom` for manual
review. The review returned
`CLEAN_WTI_SECOND_SESSION_FIRST_SESSION_REVERSAL_AFTER_FAMILY_REVIEW`:

- `QM5_41013_wti-mopen-mom` follows the first five-session aggregate from the
  sixth session through month end; this packet fades one completed session
  from the second session through the next D1 boundary.
- `QM5_12810_wti-month-orb` trades a delayed range breakout with trend/range
  filters; this packet has no range, breakout, trend indicator, or delayed
  trigger.
- `QM5_41023_wti-mends-mom` follows agreement between two prior-month segments
  from the first new-month session for five bars; this packet waits for the
  first current-month session to complete and trades its opposite for one bar.
- `QM5_41024_wti-1wed-mom1` follows the prior completed month on a weekday
  clock; this packet ignores prior-month direction and uses an ordinal-session
  reversal clock.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  multiple commodity carriers, not a WTI month-opening session reversal.

The exact first-session open/close endpoints, second-session decision,
contrarian mapping, and next-D1 lifecycle are the auditable identity. A failed
result may not be rescued by moving the clock, changing the direction,
aggregating more bars, adding a threshold, widening risk, or extending the
hold.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-16_wti_month_opening_reversal_source_approval.md` authorizes
exactly one card, deterministic ID allocation, one branch-only non-live build,
strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
session identity/endpoints/direction, current-bar leakage, late or repeated
entry, wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive
governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-build | 2026-08-16 | month-opening reversal EA, fixed-risk setfile, strict compile/build check, and static artifact validation | Q01 | PASS |
