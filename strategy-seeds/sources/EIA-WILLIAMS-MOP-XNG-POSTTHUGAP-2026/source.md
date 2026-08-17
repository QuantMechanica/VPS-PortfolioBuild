---
source_id: EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026
title: Standard-Thursday XNG event-session and post-event-gap continuation
publisher: U.S. Energy Information Administration / Wiley Trading / Journal of Financial Economics
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-17_xng_post_thursday_gap_agreement_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-17
created: 2026-08-17
created_by: Research+Development
strategy_ids:
  - EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026_S01
cards_extracted:
  - strategy-seeds/cards/approved/QM5_41052_xng-postthu-gap-agree_card.md
parent_sources:
  - EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026
  - EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026
---

# Standard-Thursday XNG Event-Session/Post-Event-Gap Source Packet

## Source Identity And Complete-Read Boundary

This bounded packet joins two already governed composite source records. Both
records were read completely before this extraction:

1. `strategy-seeds/sources/EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026/source.md`
   carries the U.S. Energy Information Administration's ordinary Thursday
   10:30 a.m. eastern-time natural-gas storage information clock, Larry R.
   Williams's prior-close/open/session price-flow decomposition, and the
   peer-reviewed own-return continuation lineage in Moskowitz, Ooi, and
   Pedersen (2012). It also records holiday-shift and XNG D1-label risk.
2. `strategy-seeds/sources/EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026/source.md`
   locks a completed event-session return plus the immediately following
   opening-gap confirmation object. Its carrier is WTI and its event clock is
   Wednesday; no WTI result or carrier claim transfers to natural gas.

The underlying primary lineage remains the EIA *Weekly Natural Gas Storage
Report* and official release schedule; Williams (1999), *Long-Term Secrets to
Short-Term Trading*, Wiley Trading; and Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. The governed XNG parent records that a
fresh generic EIA-page retrieval was `DEFERRED:SOURCE_POLICY`; no browser,
proxy, cache, authentication, or access-control workaround is used here and
no changed release-schedule claim is imported.

EIA establishes an information clock, not a tradable direction. Williams
defines price-flow segments, not this XNG rule. Moskowitz, Ooi, and Pedersen
test continuation at materially longer horizons. No source tests the exact
Thursday-event/Friday-gap conjunction, same-Friday hold, Darwinex continuous
CFD, fixed cash risk, spread ceiling, or ATR stop. No source return,
coefficient, significance, density, cost, drawdown, XNG-only efficacy, CFD
equivalence, decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026_S01` is one predeclared direct-XNG
falsification package:

- exact carrier `XNGUSD.DWX`, D1, magic slot 0;
- decide only on the first executable broker-Friday tick, no later than 180
  minutes after the executable D1 opening boundary;
- normalize energy D1 labels only by the governed native same-day or one
  uniform `+1` calendar-day convention;
- require current normalized Friday plus exact immediately completed
  Thursday, Wednesday, and Tuesday sessions, with no shifted or missing-day
  substitute;
- persist the broker-Friday attempt before history, signal, news, spread,
  quote, ATR, sizing, or order gates and never retry it;
- compute the completed Thursday open-to-close event-session log flow and the
  frozen current-Friday open relative to Thursday close;
- require both components finite, nonzero, and strictly equal in sign;
- reconcile their sum to the exact Thursday-open-to-Friday-open return;
- follow that confirmed sign at the first executable Friday tick;
- flatten through framework Friday close at broker hour 21, with first-later-
  D1 and four-calendar-day repair only for a survivor;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target;
  and
- use no inventory value, surprise, forecast, external feed, magnitude
  threshold, volatility gate, moving line, oscillator, breakout, retry,
  scale-in, grid, martingale, hedge, or pyramid.

The ordinary-Thursday clock is deliberately a price-only event proxy. Exact
Tuesday-Wednesday-Thursday history rejects many holiday-shift weeks, but native
D1 prices cannot prove that every accepted Thursday contained an ordinary EIA
release. Residual event misclassification is a Q02 kill risk.

The current Friday D1 bar's opening price is frozen at the bar boundary and is
the only current-bar field admitted. Friday high, low, close, tick volume,
post-open quotes, and every later intrabar observation are forbidden from the
signal.

## Exact Signal Contract

At the first executable broker-Friday tick after the exact completed Thursday:

```text
event_session_flow = ln(ThursdayClose / ThursdayOpen)
post_event_gap      = ln(FridayOpen / ThursdayClose)
confirmed_path      = ln(FridayOpen / ThursdayOpen)
total_flow          = event_session_flow + post_event_gap

require event_session_flow * post_event_gap > 0
require abs(total_flow - confirmed_path) <= 1e-10

total_flow > 0 => BUY XNGUSD.DWX
total_flow < 0 => SELL XNGUSD.DWX
otherwise      => consume Friday flat
```

All signal information is fixed at or before the Friday opening boundary.
Opposition, exact zero, invalid arithmetic, a broken calendar sequence, or
failed reconciliation consumes Friday without a trade. Signal magnitude never
changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: governed official EIA event
  lineage, complete Tier-A Williams price-flow extraction lineage, and a
  complete-paper receipt for peer-reviewed JFE continuation evidence that
  includes natural gas. The untested conjunction, same-session horizon, and
  carrier translation are explicit.
- R2 `PASS`: weekday identity, one uniform label convention, frozen Friday
  opening endpoint, strict agreement, reconciliation, continuation side,
  durable attempt, grace, risk, stop, spread, and Friday close are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC plus
  native MT5 calendar and execution state supply every runtime input. The
  standard-Thursday proxy and D1 label convention remain falsifiable.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,539 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy identity. Manual
family review fixes the load-bearing boundaries:

- `QM5_41043_xng-thu-flow-agree` compares Wednesday-close-to-Thursday-open
  with Thursday-open-to-close; both inputs are complete by Thursday close. It
  enters Friday and holds across the weekend. This package instead requires
  completed Thursday event-session flow to agree with the later Thursday-
  close-to-frozen-Friday-open gap and is flat Friday night.
- `QM5_41044_xng-thu-flow-fade` requires opposed components inside completed
  Thursday, strict session dominance, and a contrarian side. This package
  requires cross-boundary agreement and follows it.
- `QM5_41047_xng-thu-trend-pb` and `QM5_41048_xng-thu-trend-agree` combine the
  completed Thursday return with a 252-session trend state and hold to the
  next D1 boundary. This package has no slow trend and uses Friday's frozen
  opening gap as its independent confirmation.
- `QM5_12898_xng-eia-multiday-drift` requires event-range, body, close-location,
  moving-average, and multiday-hold conditions. This package has none of those
  gates; strict post-event opening-gap agreement and same-Friday exit are
  load-bearing.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` trade M30 release impulse,
  reclaim, or live breakout objects inside the report session. This package
  waits for completed D1 event flow and the next opening boundary.
- `QM5_20160_xng-fri-trend` is short-only from a negative completed 252-D1
  return and explicitly omits the Thursday-close-to-Friday-open gap. This
  package is symmetric and requires that gap.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not an event-time cross-boundary continuation rule.

Manual verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_FRIDAY_SESSION_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.
The XNG carrier, Thursday event-session endpoint, frozen Friday-open endpoint,
strict agreement, Friday attempt, and same-Friday exit are jointly
load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_xng_post_thursday_gap_agreement_source_approval.md`
authorize exactly one card, deterministic ID and magic allocation, one branch-
only non-live build, strict Q01 validation, one `RISK_FIXED` backtest setfile,
and one paced target-only Q02 enqueue only below the tester and host-CPU
ceilings.

They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; correlation claims; and correlation
waivers. Q09 alone may establish realized correlation with the certified book.

Expected cadence is approximately twelve to twenty-eight completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
absent strict agreement, wrong continuation side, failed reconciliation,
current-price leakage beyond Friday open, late or repeated entry, wrong Friday
lifecycle, nondeterminism, invalid risk mode, or an unusable standard-Thursday
proxy.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
