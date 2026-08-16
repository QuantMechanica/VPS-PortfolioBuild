---
source_id: GORSKA-YANG-WTI-1FRI-REV1-2026
title: WTI first-Friday premium after a negative completed calendar month
publisher: Quantitative Methods in Economics / SSRN
source_type: academic_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_wti_first_friday_reversal_source_approval.md
approval_commit: 5b0bd7603
strategy_ids:
  - GORSKA-YANG-WTI-1FRI-REV1-2026_S01
parent_sources:
  - GORSKA-WTI-CAL-2015
  - YANG-COMM-REVERSAL-2017
---

# WTI First-Friday / Prior-Month Reversal Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed academic source lineages whose
repository extractions were read completely before card drafting:

1. Anna Gorska and Malgorzata Krawiec (2015), "Calendar Effects in the
   Market of Crude Oil," *Quantitative Methods in Economics* 16(4). The
   governed extraction at
   `strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md` records Friday as
   the strongest positive average WTI weekday in the paper's sample.
2. Liu Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. The governed extraction at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` supplies the
   commodity-reversal lineage and documents monthly and four-week loser-fade
   translations on registered energy carriers.

Gorska and Krawiec supply only the positive Friday direction. Yang, Goncu,
and Pantelous supply only the fixed-horizon commodity-reversal family.
Neither source tests the exact first-Friday/prior-month conjunction, a
Darwinex continuous CFD, normalized broker labels, fixed cash risk, an ATR
stop, or the V5 Friday-close implementation. No source performance,
significance, cost, drawdown, WTI-only efficacy, CFD equivalence, correlation,
or portfolio result transfers.

## Bounded Mechanization

`GORSKA-YANG-WTI-1FRI-REV1-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day
  energy convention and require the normalized date to equal broker date;
- decide only on the first normalized Friday of the month, day `[1,7]`, when
  the immediately preceding normalized D1 label is Thursday;
- admit only the first observed tick within 180 minutes of the executable D1
  open, with no holiday substitution or late backfill;
- persist the broker-month attempt before every fallible gate;
- reconstruct the newest completed D1 close in each of the two broker months
  preceding the decision month and require exact consecutive month keys;
- compute `log(PriorMonthEnd / PriorPriorMonthEnd)` from those completed
  endpoints only;
- BUY WTI only when the completed-month return is strictly negative;
- exact zero, invalid endpoints, or a nonnegative state consumes the month
  flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- flatten through the framework Friday-close guard at broker hour 21, with
  the first later D1 boundary and four-calendar-day limit as repair; and
- use no external runtime data, magnitude scaling, retry, scale-in, grid,
  martingale, or pyramid.

The first-Friday selector deliberately creates a one-decision-per-month
interaction rather than another weekly Friday fanout. It and the completed-
calendar-month endpoint convention, 180-minute attachment boundary, risk,
stop, spread, and lifecycle are disclosed QM choices.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named authors, durable
  academic source identities, complete governed repository extractions, and
  explicit WTI/commodity relevance. The working-paper status, untested
  conjunction, multiple-testing risk, and post-sample decay are disclosed.
- R2 `PASS`: first-Friday identity, normalized labels, completed month
  endpoints, reversal sign, direction, attempt state, entry timing, risk,
  stop, spread, Friday close, and repair are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history and MT5 execution state supply
  every runtime input; the energy label offset is measured in the registry.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR, quote, position,
  deal-history, and framework state only; no trained output, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,513 EA-registry rows and 609 root
cards and returned `CLEAN` without exact or fuzzy matches. Manual review
returned
`CLEAN_WTI_FIRST_FRIDAY_PRIOR_MONTH_REVERSAL_AFTER_FAMILY_REVIEW`:

- `QM5_20172_wti-fri-bear` uses every genuine Friday and a completed 252-D1
  negative state; this packet uses one Friday per month and exact preceding
  calendar-month endpoints.
- `QM5_12597_wti-fri-prem` is unconditional and weekly.
- `QM5_12709_commodity-reversal-1m` is a four-carrier cross-sectional
  two-leg monthly basket, not a direct WTI one-session calendar interaction.
- `QM5_12621_comm-reversal-4wk-xtiusd` reads a rolling 20-D1 overreaction
  threshold rather than consecutive calendar-month endpoints.
- `QM5_41024_wti-1wed-mom1` follows both prior-month signs on first Wednesday;
  this packet fades only the negative sign on first Friday and uses Friday
  close.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback fanout, not
  a structural WTI calendar/reversal rule.

The first-genuine-Friday clock, exact prior-calendar-month state, negative-
only long direction, and Friday-session lifecycle are the auditable identity.
A failed result may not be rescued by shifting the day, changing the horizon
or sign, admitting every Friday, widening risk, or extending the hold.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-16_wti_first_friday_reversal_source_approval.md` authorizes
exactly one card, deterministic ID allocation, one branch-only non-live
build, strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02
enqueue.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately four to eight completed positions per full
post-warm-up year. Q02 must retire on zero trades, below three/year, wrong
dates or endpoints, current-bar leakage, late or repeated entry, wrong side,
wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive governed
economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
