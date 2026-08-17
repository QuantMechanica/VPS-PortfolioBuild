---
source_id: WILLIAMS-MOP-WTI-MFLOWDOM-2026
title: WTI monthly opposed-information-flow dominance rule
publisher: Wiley Trading / Journal of Financial Economics
source_type: book_and_peer_reviewed_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_wti_monthly_opposed_flow_dominance_source_approval.md
approval_commit: 81183098b
strategy_ids:
  - WILLIAMS-MOP-WTI-MFLOWDOM-2026_S01
cards_extracted:
  - strategy-seeds/cards/approved/QM5_41036_wti-mflow-dom_card.md
parent_sources:
  - SRC03
  - MOP-TSMOM-2012
---

# WTI Monthly Opposed-Flow Dominance Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed source lineages whose repository
extractions were read completely before card drafting:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A record is
   `strategy-seeds/sources/SRC03/source.md`. The complete bounded page-15-to-30
   text at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` defines daily
   close-to-open public flow and open-to-close professional flow, says the
   separate lines can reveal what is really happening, and identifies
   divergences as potentially useful.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper receipt and findings at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` identify WTI as an
   explicit commodity-futures carrier and delimit the one-month formation,
   one-month hold commodity-momentum family.

Williams does not test WTI, monthly aggregation, strict component opposition,
new-month entry, dominant-component direction, or a one-month hold. Moskowitz,
Ooi, and Pedersen do not decompose returns by information time or support the
opposition gate. Neither source tests the conjunction, Darwinex continuous
CFDs, normalized broker labels, fixed cash risk, or an ATR stop. No source
performance, significance, cost, density, drawdown, WTI-only efficacy, CFD
equivalence, correlation, or portfolio result transfers.

## Bounded Mechanization

`WILLIAMS-MOP-WTI-MFLOWDOM-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day energy
  convention and require normalized current date to equal broker date;
- decide only on the first genuine D1 boundary of a new broker month, within
  180 minutes of executable D1 open;
- persist the exact broker-month attempt before every fallible gate;
- require the immediately completed month, its preceding month-end anchor,
  consecutive month keys, strict timestamp order, and 15-25 completed
  prior-month sessions;
- sum all completed close-to-open log returns separately from all completed
  open-to-close log returns;
- require the component sums to have strict opposite signs and reconcile their
  total to the completed month-end-to-month-end log return;
- require strict opposition, then follow whichever component has larger
  absolute magnitude: positive dominant flow buys and negative dominant flow
  sells; equal magnitude, agreement, exact zero, invalid state, or failed
  reconciliation is flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- renew at the first next-month boundary, with a 40-calendar-day stale guard;
  and
- use no external runtime data, magnitude threshold,
  volatility gate, moving line, crossover, retry, scale-in, grid, martingale,
  or pyramid.

The exact completed-month selector, information-time decomposition, strict
opposition, absolute-dominance direction, reconciliation, 180-minute
attachment boundary, risk, stop, spread, and lifecycle are disclosed QM
choices. The sources do not test this interaction or Darwinex carrier.

## Exact Signal Contract

For every completed session `d` in the immediately prior normalized broker
month, with positive finite prices and the preceding month-end as the oldest
anchor:

```text
overnight_flow = sum(log(Open[d] / Close[prior_session]))
session_flow   = sum(log(Close[d] / Open[d]))
month_return   = log(PriorMonthEndClose / PriorPriorMonthEndClose)
total_flow     = overnight_flow + session_flow

require sign(overnight_flow) = -sign(session_flow) != 0
require total_flow reconciles to month_return

abs(session_flow) > abs(overnight_flow) => direction = sign(session_flow)
abs(overnight_flow) > abs(session_flow) => direction = sign(overnight_flow)
equal magnitude or any ineligible state => consume month flat
```

All endpoints are completed before the decision month. The current live D1
bar enters no signal term. Component magnitude selects direction only; it
never scales risk.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named sources, one complete
  OWNER-supplied Tier-A book extraction, one complete-read peer-reviewed JFE
  paper, explicit WTI carrier relevance, and one bounded lineage ID. The
  untested conjunction and adverse source scope are explicit.
- R2 `PASS`: exact month identity, normalized labels, all completed
  close/open endpoints, strict opposition, reconciliation, direction, attempt
  state, entry timing, risk, stop, spread, and exit are deterministic.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and MT5 execution state supply
  every runtime input. The direct WTI D1 session offset is governed by
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,523 EA-registry rows and 619 card
files. It found no exact identity and raised the expected monthly agreement
and weekly opposed-flow family neighbors. Manual review returned
`CLEAN_WTI_MONTHLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`:

- `QM5_41034_wti-mflow-agree` trades only strict monthly component agreement;
  this packet trades only strict opposition, a disjoint eligible state;
- `QM5_41032_wti-flow-div` forms on one exact Monday-Friday week, decides the
  next Monday, and exits Friday; this packet consumes one entire completed
  broker month and holds until the next month;
- `QM5_41033_wti-flow-dom` follows the reconciled total/dominant component of
  one opposed-flow week; this packet applies the dominance rule to a complete
  broker month and holds until the next month;
- `QM5_20187_wti-tsmom1m` follows every nonzero completed-month total; this
  packet rejects agreement months and admits only strict opposition, while
  the existing card admits every nonzero completed-month total;
- `QM5_41023_wti-mends-mom` compares close-to-close boundary segments and
  holds five sessions rather than splitting every interval and holding a
  broker month;
- `QM5_12784_progo-xti` uses fourteen-day signed-value moving-line crossings
  on any D1 bar rather than raw monthly log sums at one fixed boundary; and
- `QM5_12567_cum-rsi2-commodity` is a long-only oscillator pullback.

The immediately completed broker month, every component endpoint, strict
opposition, reconciliation, absolute-dominance direction, first-new-month
decision, and next-month renewal are the auditable identity. A failed result
may not be rescued by admitting agreement, following a fixed component, adding a
threshold/filter, moving the clock, changing the formation month, or
shortening/extending the hold.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_wti_monthly_opposed_flow_dominance_source_approval.md` authorize
exactly one card, deterministic ID allocation, one branch-only non-live build,
strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue if CPU
capacity permits.

They exclude manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately five to eight completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five/year, wrong month
identity or endpoints, current-bar leakage, entry on component agreement,
wrong direction, failed reconciliation, late or repeated entry, wrong
lifecycle, nondeterminism, invalid risk mode, or nonpositive governed
economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-17 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
| v1-build | - | deterministic EA and fixed-risk set | Q01 | PENDING |
| v1-q02 | - | paced target-only WTI baseline row | Q02 | PENDING_CAPACITY |
