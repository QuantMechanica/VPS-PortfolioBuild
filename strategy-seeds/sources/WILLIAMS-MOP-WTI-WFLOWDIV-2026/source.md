---
source_id: WILLIAMS-MOP-WTI-WFLOWDIV-2026
title: WTI weekly public/professional flow-divergence session-follow rule
publisher: Wiley Trading / Journal of Financial Economics
source_type: book_and_peer_reviewed_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_wti_weekly_flow_divergence_source_approval.md
approval_commit: ae0550fda
strategy_ids:
  - WILLIAMS-MOP-WTI-WFLOWDIV-2026_S01
cards_extracted:
  - wti-flow-div
parent_sources:
  - SRC03
  - MOP-TSMOM-2012
---

# WTI Weekly Public/Professional Flow-Divergence Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed source lineages whose repository
extractions were read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record is
   `strategy-seeds/sources/SRC03/source.md`. The complete bounded page-18 text
   at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` defines the daily
   close-to-open public-flow change and open-to-close professional-flow
   change, then describes separate averages, divergences, and crossings.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` identify WTI as an
   explicit commodity-futures carrier and delimit the source's own-return
   continuation result.

Williams does not test WTI, a five-session component-sign opposition state, a
Monday entry, a session-following direction, or a Friday exit. Moskowitz,
Ooi, and Pedersen do not decompose returns by close/open information time and
do not support the proposed opposition rule. Neither source tests the
conjunction, a Darwinex continuous CFD, normalized broker labels, fixed cash
risk, or an ATR stop. No source performance, significance, cost, density,
drawdown, WTI-only efficacy, CFD equivalence, correlation, or portfolio result
transfers.

## Bounded Mechanization

`WILLIAMS-MOP-WTI-WFLOWDIV-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day
  energy convention and require normalized current date to equal broker date;
- decide only on the first genuine normalized Monday after one exact completed
  Monday-through-Friday week, within 180 minutes of executable D1 open;
- require the prior five sessions and preceding Friday to form the exact
  Monday-through-Friday-plus-anchor sequence; never shift a holiday;
- persist the exact broker-Monday attempt before every fallible gate;
- sum five fixed completed close-to-open log returns separately from the five
  fixed completed open-to-close log returns;
- BUY only when session flow is strictly positive and overnight flow is
  strictly negative; SELL only when session flow is strictly negative and
  overnight flow is strictly positive; agreement or equality is flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- use framework Friday close at broker hour 21 as the ordinary exit, with a
  later-week boundary and eight-calendar-day stale guard; and
- use no external runtime data, magnitude threshold, volatility gate, moving
  line, crossover, retry, scale-in, grid, martingale, or pyramid.

The exact-week selector, return decomposition, strict opposition,
session-following direction, 180-minute attachment boundary, risk, stop,
spread, and lifecycle are disclosed QM choices. The sources do not test this
interaction or one-week hold.

## Exact Signal Contract

For the five completed prior-week sessions `d`, with positive finite prices:

```text
overnight_flow = sum(log(Open[d] / Close[prior_session]))
session_flow   = sum(log(Close[d] / Open[d]))

session_flow > 0 and overnight_flow < 0 => BUY XTIUSD.DWX
session_flow < 0 and overnight_flow > 0 => SELL XTIUSD.DWX
otherwise                                => consume week flat
```

All endpoints are completed before the current Monday. Exact zero is flat.
Signal magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named sources, one complete
  OWNER-supplied Tier-A book extraction, one complete-read peer-reviewed JFE
  paper, explicit WTI carrier relevance, and one bounded lineage ID. The
  untested conjunction and adverse source scope are explicit.
- R2 `PASS`: exact prior-week identity, normalized labels, completed
  close/open endpoints, strict opposition, direction, attempt state, entry
  timing, risk, stop, spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and MT5 execution state supply
  every runtime input. The direct WTI D1 session offset is governed by
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,519 EA-registry rows and 615 root
cards. It found no exact identity and the expected fuzzy family neighbor
`QM5_41029_wti-flow-agree`, plus the irrelevant slug-token neighbor
`QM5_21520_xng-flow-mom`. Manual review returned
`CLEAN_WTI_WEEKLY_PUBLIC_PROFESSIONAL_FLOW_DIVERGENCE_AFTER_FAMILY_REVIEW`:

- `QM5_41029_wti-flow-agree` enters only when the two weekly component signs
  agree and follows their common sign; this rule is flat on every agreement
  state, enters only strict opposition, and follows the session component;
- `QM5_12784_progo-xti` compares fourteen-day signed-value averages and
  trades line crossings on any D1 bar; this packet uses two five-session log
  sums, no moving line or crossing, and an exact weekly clock;
- `QM5_41030_xauxag-flowdiv` subtracts silver flows from gold flows and trades
  an equal-notional two-metal basket; this packet performs no cross-metal
  calculation and trades one WTI position;
- `QM5_21520_xng-flow-mom` uses a five-close XNG return gated by a disjoint
  tick-volume rank and has none of this packet's carrier, endpoints, state, or
  lifecycle; and
- `QM5_12567_cum-rsi2-commodity` is an oscillator pullback rather than a
  structural WTI flow decomposition.

The exact completed-week sequence, two information-time components, strict
opposition, session-following direction, next-Monday decision, and Friday
lifecycle are the auditable identity. A failed result may not be rescued by
adding thresholds, accepting agreement, reversing the session component,
changing the weekday sequence, adding a line crossover, or extending the
hold.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-16_wti_weekly_flow_divergence_source_approval.md` authorize
exactly one card, deterministic ID allocation, one branch-only non-live build,
strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue if CPU
capacity permits.

They exclude manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
week identity or flow endpoints, current-bar leakage, entry on agreement,
direction opposite the session flow, late or repeated entry, wrong lifecycle,
nondeterminism, invalid risk mode, or nonpositive governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-16 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic EA, fixed-risk setfile, strict compile/build check, reference suite, and static artifact validation | Q01 | PASS |
| v1-q02 | 2026-08-17 | one target-only paced baseline row enqueued below the factory ceiling | Q02 | ENQUEUED |
