---
source_id: WILLIAMS-MOP-XNG-WFLOW-2026
title: XNG weekly overnight/session flow-agreement continuation
publisher: Wiley Trading / Journal of Financial Economics
source_type: book_and_peer_reviewed_composite_lineage
status: approved
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
approved_by: "OWNER commodity/energy portfolio mission 2026-08-18"
approved_at: 2026-08-18
source_approval: decisions/2026-08-18_xng_weekly_flow_agreement_source_approval.md
approval_commit: PENDING_SOURCE_COMMIT
strategy_ids:
  - WILLIAMS-MOP-XNG-WFLOW-2026_S01
cards_extracted: []
parent_sources:
  - WILLIAMS-MOP-WTI-WFLOW-2026
  - MOP-TSMOM-2012
---

# XNG Weekly Flow-Agreement Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed records read completely before card
drafting:

1. The exact-week Williams lineage at
   `strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOW-2026/source.md`, backed by
   Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, and the OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md`. Williams defines separate daily
   prior-close-to-open and open-to-close flow objects and studies their
   interaction. The governed packet fixes the exact completed-week endpoint
   map; its WTI carrier is not inherited.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper record at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` supplies own-return
   continuation lineage, natural-gas membership in the diversified commodity
   universe, and the limitation that pooled futures results do not establish
   an XNG CFD result.

Williams does not test natural gas or a weekly agreement conjunction.
Moskowitz, Ooi, and Pedersen do not decompose weekly returns by close/open
information time. Neither tests a Darwinex continuous CFD, normalized energy
labels, a Monday-to-Friday hold, fixed cash risk, or an ATR hard stop. No
source performance, significance, cost, density, drawdown, XNG-only efficacy,
CFD equivalence, neutrality, decorrelation, or portfolio result transfers.

## Bounded Mechanization

`WILLIAMS-MOP-XNG-WFLOW-2026_S01` is one predeclared direct-XNG package:

- exact carrier `XNGUSD.DWX`, D1, magic slot 0;
- accept only native same-day D1 labels or one uniform `+1`-day energy
  convention, with normalized current date equal to broker date;
- decide only on the first executable normalized Monday after one exact
  completed Monday-through-Friday week, within 180 minutes of D1 open;
- require the prior five sessions and preceding Friday to form the exact
  Monday-through-Friday-plus-anchor sequence; never shift a holiday;
- persist the exact broker-Monday attempt before every fallible gate;
- sum five completed close-to-open log returns separately from five completed
  open-to-close log returns and reconcile their total to the completed weekly
  endpoint within `1e-10`;
- BUY when both sums are strictly positive and SELL when both are strictly
  negative; disagreement, equality, failed reconciliation, or invalid data
  consumes the week flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 3,000-point XNG spread ceiling, and no
  target;
- use framework Friday close at broker hour 21 as the ordinary exit, with a
  later-week boundary and eight-calendar-day stale guard; and
- use no external runtime data, magnitude threshold, volatility signal gate,
  line crossover, retry, scale-in, grid, martingale, or pyramid.

The exact-week selector, return decomposition, agreement rule, continuation
direction, 180-minute boundary, durable attempt, risk, stop, spread, and
lifecycle are disclosed QM choices. The sources do not test this interaction
or one-week XNG hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named authors, a complete
  OWNER-supplied Tier-A practitioner lineage, a complete-read peer-reviewed
  JFE paper with DOI and natural-gas membership, and an explicit XNG carrier
  translation.
- R2 `PASS`: exact prior-week identity, uniform labels, completed close/open
  endpoints, strict agreement, reconciliation, direction, attempt state,
  entry timing, risk, stop, spread, and exit are fixed.
- R3 `PASS`: registered `XNGUSD.DWX` D1 OHLC and native MT5 state supply all
  runtime inputs; Q02 owns current route and fill validation.
- R4 `PASS`: native calendar, OHLC, logarithms, comparisons, ATR risk
  plumbing, quote, position, deal history, and framework state only; no
  trained output, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,545 EA-registry rows and 625 root
cards. It found no exact identity and four expected source-family fuzzy hits.
Manual review returned
`CLEAN_XNG_WEEKLY_OVERNIGHT_SESSION_FLOW_AGREEMENT_CARRIER_AFTER_FAMILY_REVIEW`:

- `QM5_41029_wti-flow-agree` is the frozen WTI carrier. This packet is the
  explicitly authorized XNG carrier with distinct underlying, history,
  contract, liquidity, gap, and seasonal risk; it cannot trade WTI.
- WTI flow-opposition siblings admit the opposite component state and trade a
  different carrier.
- `QM5_41037_xng-mflow-div` and `QM5_41038_xng-mflow-dom` require a complete
  month and opposed components. This packet requires one exact week and
  agreement.
- `QM5_41043_xng-thu-flow-agree` observes one completed standard-Thursday
  proxy and enters Friday. This packet observes an entire completed week and
  enters Monday.
- `QM5_13101_xng-1w-mom-vol` requires close-return magnitude and a volatility
  gate; this packet has neither and uses information-time agreement.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a symmetric weekly continuation rule.

Carrier, exact prior-week sequence, uniform label convention, ten component
endpoints, strict agreement, continuation direction, Monday decision, and
Friday lifecycle jointly define the identity. A failed result may not be
rescued by changing them or adding a threshold or filter.

## Safety And Extraction Boundary

The approval at
`decisions/2026-08-18_xng_weekly_flow_agreement_source_approval.md`
authorizes exactly one card, deterministic allocation, one branch-only
non-live build, strict Q01, one `RISK_FIXED` backtest setfile, and one paced
Q02 enqueue when capacity permits.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
week identity or endpoints, current-bar leakage, entry on disagreement, late
or repeated entry, wrong lifecycle, nondeterminism, invalid risk mode,
unusable XNG history, or nonpositive governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-18 | bounded XNG carrier extraction | G0 | APPROVED_SOURCE |

