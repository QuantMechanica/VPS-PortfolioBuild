---
source_id: WILLIAMS-MOP-WTI-WFLOWDOM-2026
title: WTI weekly opposed-flow dominance continuation rule
publisher: Wiley Trading / Journal of Financial Economics
source_type: book_and_peer_reviewed_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_wti_weekly_flow_dominance_source_approval.md
approval_commit: 1447c6ba8
strategy_ids:
  - WILLIAMS-MOP-WTI-WFLOWDOM-2026_S01
cards_extracted:
  - wti-flow-dom
parent_sources:
  - SRC03
  - MOP-TSMOM-2012
---

# WTI Weekly Opposed-Flow Dominance Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed source lineages whose repository
extractions were read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record is
   `strategy-seeds/sources/SRC03/source.md`. The complete bounded page-15-to-30
   text at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` defines daily
   close-to-open public flow and open-to-close professional flow, then
   describes separate averages, divergences, and crossings.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` identify WTI as an
   explicit commodity-futures carrier and delimit the source's own-return
   continuation result.

Williams does not test WTI, five-session component aggregation, strict sign
opposition, absolute-flow dominance, Monday entry, or Friday exit. Moskowitz,
Ooi, and Pedersen do not decompose returns by close/open information time and
do not support the proposed opposition gate. Neither source tests the
conjunction, Darwinex continuous CFDs, normalized broker labels, fixed cash
risk, or an ATR stop. No source performance, significance, cost, density,
drawdown, WTI-only efficacy, CFD equivalence, correlation, or portfolio result
transfers.

## Bounded Mechanization

`WILLIAMS-MOP-WTI-WFLOWDOM-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day energy
  convention and require normalized current date to equal broker date;
- decide only on the first genuine normalized Monday after one exact completed
  Monday-through-Friday week, within 180 minutes of executable D1 open;
- require the prior five sessions and preceding Friday to form the exact
  Monday-through-Friday-plus-anchor sequence; never shift a holiday;
- persist the exact broker-Monday attempt before every fallible gate;
- sum five completed close-to-open log returns separately from five completed
  open-to-close log returns;
- require the two component signs to oppose and reconcile their sum to the
  completed Friday-to-Friday log return;
- BUY when the reconciled total is positive and SELL when negative, thereby
  following the component with larger absolute magnitude; tie or equality is
  flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- use framework Friday close at broker hour 21 as the ordinary exit, with a
  later-week boundary and eight-calendar-day stale guard; and
- use no external runtime data, magnitude threshold, volatility gate, moving
  line, crossover, retry, scale-in, grid, martingale, or pyramid.

The exact-week selector, return decomposition, strict opposition,
reconciliation, dominant-flow direction, 180-minute attachment boundary,
risk, stop, spread, and lifecycle are disclosed QM choices. The sources do
not test this interaction or one-week hold.

## Exact Signal Contract

For the five completed prior-week sessions `d`, with positive finite prices:

```text
overnight_flow = sum(log(Open[d] / Close[prior_session]))
session_flow   = sum(log(Close[d] / Open[d]))
week_return    = log(PriorFridayClose / PrecedingFridayClose)
total_flow     = overnight_flow + session_flow

require sign(overnight_flow) = -sign(session_flow)
require total_flow reconciles to week_return

total_flow > 0 => BUY XTIUSD.DWX
total_flow < 0 => SELL XTIUSD.DWX
otherwise      => consume week flat
```

All endpoints are completed before the current Monday. Exact zero and equal
component magnitude are flat. Signal magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named sources, one complete
  OWNER-supplied Tier-A book extraction, one complete-read peer-reviewed JFE
  paper, explicit WTI carrier relevance, and one bounded lineage ID. The
  untested conjunction and adverse source scope are explicit.
- R2 `PASS`: exact prior-week identity, normalized labels, completed
  close/open endpoints, strict opposition, reconciliation, direction, attempt
  state, entry timing, risk, stop, spread, and exit are deterministic.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and MT5 execution state supply
  every runtime input. The direct WTI D1 session offset is governed by
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,520 EA-registry rows and 616 card
files. It found no exact identity and raised the expected family neighbors.
Manual review returned
`CLEAN_WTI_WEEKLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`:

- `QM5_41032_wti-flow-div` trades the same opposition state but follows the
  session component regardless of magnitude. This packet follows the
  reconciled total/dominant component, so it agrees only when session
  magnitude dominates, reverses when overnight dominates, and is flat on a
  tie;
- `QM5_41029_wti-flow-agree` trades only same-sign components, a disjoint
  eligible state;
- `QM5_41022_wti-wdual-mom` splits close-to-close price into early/late weekly
  segments rather than decomposing every session by information time;
- `QM5_13049_xti-1w-mom-vol` uses a rolling return threshold and volatility
  rank instead of exact-calendar opposition and reconciliation;
- `QM5_12784_progo-xti` trades fourteen-day signed-value line crossings on any
  D1 bar rather than fixed weekly log sums;
- `QM5_10316_overnight-intraday-reversal` is a same-session cross-sectional
  rank basket; and
- `QM5_21520_xng-flow-mom` and `QM5_12567_cum-rsi2-commodity` use a different
  carrier and/or signal family.

The exact completed-week sequence, two information-time components, strict
opposition, reconciliation, dominant-component direction, next-Monday
decision, and Friday lifecycle are the auditable identity. A failed result may
not be rescued by adding thresholds, accepting agreement, always following
one named component, changing the weekday sequence, adding a line crossover,
or extending the hold.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_wti_weekly_flow_dominance_source_approval.md` authorize
exactly one card, deterministic ID allocation, one branch-only non-live build,
strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue if CPU
capacity permits.

They exclude manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
week identity or endpoints, current-bar leakage, entry on agreement, direction
different from the reconciled total, failed reconciliation, late or repeated
entry, wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive
governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-17 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic V5 build, strict compile, and static validation | Q01 | PASS |
