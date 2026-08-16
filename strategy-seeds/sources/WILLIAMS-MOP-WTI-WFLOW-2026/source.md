---
source_id: WILLIAMS-MOP-WTI-WFLOW-2026
title: WTI weekly overnight/session flow-agreement continuation
publisher: Wiley Trading / Journal of Financial Economics
source_type: book_and_peer_reviewed_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_wti_weekly_flow_agreement_source_approval.md
approval_commit: ed9953241a1e8d15c8888e2019967d88cc3f21ec
strategy_ids:
  - WILLIAMS-MOP-WTI-WFLOW-2026_S01
parent_sources:
  - SRC03
  - MOP-TSMOM-2012
---

# WTI Weekly Flow-Agreement Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed source lineages whose repository
extractions were read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record is
   `strategy-seeds/sources/SRC03/source.md`. The bounded page-18 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` defines the daily
   close-to-open public-flow change and open-to-close professional-flow
   change, then describes fourteen-day averages, divergences, and crossings.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` supply own-return-sign
   continuation lineage and explicit WTI membership in the commodity sample.

Williams does not test WTI, weekly component-sign agreement, a Monday entry,
or a Friday exit. Moskowitz, Ooi, and Pedersen do not decompose weekly returns
by close/open information time. Neither source tests the conjunction, a
Darwinex continuous CFD, normalized broker labels, fixed cash risk, or an ATR
stop. No source performance, significance, cost, drawdown, WTI-only efficacy,
CFD equivalence, correlation, or portfolio result transfers.

## Bounded Mechanization

`WILLIAMS-MOP-WTI-WFLOW-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day
  energy convention and require normalized current date to equal broker date;
- decide only on the first genuine normalized Monday after one exact completed
  Monday-through-Friday week, within 180 minutes of executable D1 open;
- require the prior five sessions and preceding Friday to form the exact
  Monday-through-Friday-plus-anchor sequence; never shift a holiday;
- persist the broker-week attempt before every fallible gate;
- sum five fixed completed close-to-open log returns separately from the five
  fixed completed open-to-close log returns;
- BUY when both sums are strictly positive and SELL when both are strictly
  negative; disagreement, equality, or invalid data consumes the week flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- use framework Friday close at broker hour 21 as the ordinary exit, with a
  later-week boundary and eight-calendar-day stale guard; and
- use no external runtime data, flow threshold, volatility gate, line
  crossover, retry, scale-in, grid, martingale, or pyramid.

The exact-week selector, return decomposition, agreement rule, 180-minute
attachment boundary, risk, stop, spread, and lifecycle are disclosed QM
choices. The sources do not test this interaction or one-week hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named sources, one OWNER-supplied
  Tier-A book extraction, one complete-read peer-reviewed JFE paper, explicit
  commodity/WTI relevance, and one bounded lineage ID. The untested
  conjunction and source-to-implementation distance are explicit.
- R2 `PASS`: exact prior-week identity, normalized labels, completed
  close/open endpoints, strict agreement, direction, attempt state, entry
  timing, risk, stop, spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and MT5 execution state supply
  every runtime input. The direct WTI D1 session offset is measured in
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,516 EA-registry rows and 612 root
cards. It found no exact identity and the expected fuzzy family neighbor
`QM5_41019_wti-wopen-mom`. Manual review returned
`CLEAN_WTI_WEEKLY_OVERNIGHT_SESSION_FLOW_AGREEMENT_AFTER_FAMILY_REVIEW`:

- `QM5_12784_progo-xti` compares fourteen-day signed-value averages and
  trades line crossings on any D1 bar; this packet compares the separate
  strict signs of two five-session log sums on an exact weekly clock.
- `QM5_41022_wti-wdual-mom` separates the prior close path into temporal
  opening/closing week segments; this packet separates each session into
  overnight and session information components.
- `QM5_41019_wti-wopen-mom` observes the current week's opening segment and
  enters Wednesday; this packet observes a fully completed prior week and
  enters Monday.
- `QM5_13049_xti-1w-mom-vol` requires close-return magnitude and realized-
  volatility gates; this packet requires component agreement and neither
  threshold.
- `QM5_41028_wti-mgap-fade` is a one-gap monthly contrarian rule; this packet
  is a ten-component weekly continuation rule.
- `QM5_12567_cum-rsi2-commodity` is an oscillator pullback, not a structural
  WTI flow decomposition.

The close/open decomposition, exact prior-week sequence, strict component-sign
agreement, next-Monday decision, and Friday lifecycle are the auditable
identity. A failed result may not be rescued by adding thresholds, changing
the weekday sequence, replacing agreement with a crossover, changing
direction, or extending the hold.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-16_wti_weekly_flow_agreement_source_approval.md`
authorizes exactly one card, deterministic ID allocation, one branch-only
non-live build, strict Q01, one `RISK_FIXED` backtest setfile, and one paced
Q02 enqueue.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
week identity or flow endpoints, current-bar leakage, entry on disagreement,
late or repeated entry, wrong lifecycle, nondeterminism, invalid risk mode, or
nonpositive governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
