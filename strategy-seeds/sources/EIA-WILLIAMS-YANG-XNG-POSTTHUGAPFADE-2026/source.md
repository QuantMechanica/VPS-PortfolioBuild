---
source_id: EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026
title: Standard-Thursday XNG event-session and post-event counter-gap fade
publisher: U.S. Energy Information Administration / Wiley Trading / International Review of Financial Analysis
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-18_xng_post_thursday_countergap_fade_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-18
created: 2026-08-18
created_by: Research+Development
strategy_ids:
  - EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026_S01
parent_sources:
  - EIA-XNG-STORAGE-AFTERSHOCK-2026
  - SRC03
  - YANG-COMM-REVERSAL-2017
  - EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026
  - EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026
---

# Standard-Thursday XNG Post-Event Counter-Gap Source Packet

## Source Identity And Complete-Read Boundary

This bounded packet joins governed source records read completely before card
extraction:

1. `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`
   preserves the U.S. Energy Information Administration's ordinary Thursday
   10:30 a.m. eastern-time natural-gas storage information clock and the fact
   that federal-holiday weeks can shift the release.
2. `strategy-seeds/sources/SRC03/source.md` and the complete bounded extraction
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` preserve Larry R.
   Williams's prior-close/open/session price-flow decomposition. Williams
   treats close-to-open and open-to-close flows separately; he does not test
   natural gas, the EIA clock, or this counter-gap rule.
3. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` preserves the
   final-publication identity of Yang, Goncu, and Pantelous (2018),
   "Momentum and reversal strategies in Chinese commodity futures markets,"
   *International Review of Financial Analysis* 60, 177-196, DOI
   `10.1016/j.irfa.2018.09.012`. It supplies broad fixed-horizon commodity-
   reversal lineage. The local record is not a complete-paper receipt, its
   universe is not XNG, and its horizons do not establish this one-session
   translation.
4. `strategy-seeds/sources/EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026/source.md`
   fixes the exact XNG Thursday-event/Friday-opening endpoints and documents
   their calendar, label, and CFD translation risks. Its strategy requires
   agreement and continuation; no result or direction transfers here.
5. `strategy-seeds/sources/EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026/source.md`
   fixes the counter-gap opposition/dominance construction on WTI's different
   Wednesday information clock. No WTI result or carrier claim transfers to
   natural gas.

The deterministic source router was run against
`https://www.eia.gov/naturalgas/storage/` on 2026-08-18 and returned
`DEFERRED:SOURCE_POLICY` because the generic adapter is router-only. No proxy,
cache, browser, authentication, or access-control workaround was attempted.
This packet imports no new webpage text or changed schedule claim and relies
only on the existing OWNER-approved repository record.

EIA establishes an information clock, not a tradable direction. Williams
defines price-flow segments, not this XNG rule. Yang, Goncu, and Pantelous do
not test this carrier, event, endpoint conjunction, or horizon. No source
return, coefficient, significance, density, cost, drawdown, XNG efficacy, CFD
equivalence, decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026_S01` is one predeclared direct-XNG
falsification package:

- exact carrier `XNGUSD.DWX`, D1, magic slot 0;
- decide only on the first executable broker-Friday tick, no later than 180
  minutes after the executable D1 opening boundary;
- normalize energy D1 labels only by the governed native same-day or one
  uniform `+1` calendar-day convention;
- require current normalized Friday plus exact immediately completed Thursday,
  Wednesday, and Tuesday sessions, with no shifted or missing-day substitute;
- persist the broker-Friday attempt before history, signal, news, spread,
  quote, ATR, sizing, or order gates and never retry it;
- compute the completed Thursday open-to-close event-session log flow and the
  frozen current-Friday open relative to Thursday close;
- require both components finite, nonzero, and strictly opposed, with the
  absolute event-session component strictly larger than the absolute gap;
- reconcile their sum to the exact Thursday-open-to-Friday-open return;
- trade in the still-dominant event-session sign, thereby fading only the
  smaller counter-gap;
- flatten through framework Friday close at broker hour 21, with the first
  later D1 boundary and four-calendar-day stale guard repairing only a
  survivor;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target;
  and
- use no storage value, forecast, external feed, magnitude threshold,
  dominance ratio, volatility gate, moving line, oscillator, range, tail,
  breakout, retry, scale-in, grid, martingale, hedge, or pyramid.

The ordinary-Thursday clock is deliberately a price-only event proxy. Exact
Tuesday-Wednesday-Thursday history rejects many holiday-shift weeks, but native
D1 prices cannot prove that every accepted Thursday contained an ordinary EIA
release. Residual event-clock and D1-label classification are Q02 kill risks.

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

require event_session_flow * post_event_gap < 0
require abs(event_session_flow) > abs(post_event_gap)
require abs(total_flow - confirmed_path) <= 1e-10

event_session_flow > 0 => BUY XNGUSD.DWX
event_session_flow < 0 => SELL XNGUSD.DWX
otherwise              => consume Friday flat
```

All signal information is fixed at or before the Friday opening boundary.
Agreement, exact zero, equal magnitude, counter-gap dominance, invalid
arithmetic, a broken calendar sequence, or failed reconciliation consumes the
Friday without a trade. Signal magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: governed official EIA event
  lineage, complete Tier-A Williams price-flow extraction, and a named
  peer-reviewed final-publication commodity-reversal lineage. The Yang local
  full-paper limitation, untested conjunction, same-session horizon, and XNG
  carrier translation are explicit.
- R2 `PASS`: weekday identity, one uniform label convention, frozen Friday
  opening endpoint, strict opposition, event-session dominance,
  reconciliation, counter-gap-fade side, durable attempt, grace, risk, stop,
  spread, and Friday close are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC plus
  native MT5 calendar and execution state supply every runtime input. The
  standard-Thursday proxy and D1 label convention remain falsifiable.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,541 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy identity. Manual
family review fixes the load-bearing boundaries:

- `QM5_41052_xng-postthu-gap-agree` uses the same carrier and frozen endpoints
  but requires strict cross-boundary agreement and follows the common sign.
  This package requires strict opposition plus event-session dominance and
  follows the event-session sign to fade the smaller gap; eligible states are
  disjoint.
- `QM5_41044_xng-thu-flow-fade` compares the earlier Wednesday-close-to-
  Thursday-open pre-event flow with Thursday's completed session, then holds
  across the weekend. This package compares the completed event session with
  the later Thursday-close-to-Friday-open gap and is normally flat Friday
  night.
- `QM5_41043_xng-thu-flow-agree` and `QM5_41048_xng-thu-trend-agree` never use
  the frozen Friday-opening counter-gap.
- `QM5_12898_xng-eia-multiday-drift` requires event-range, body,
  close-location, moving-average, and multiday-hold conditions absent here.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` trade M30 release impulse,
  reclaim, or live breakout objects inside the report session. This package
  waits for completed D1 event flow and the next opening boundary.
- `QM5_41053_wti-postwed-gap-fade` shares the abstract construction but uses
  WTI, a Wednesday petroleum clock, a Thursday decision, a tighter oil spread
  cap, and a next-D1 lifecycle. No carrier result transfers.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not an event-time symmetric counter-gap rule.

Manual verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.
The XNG carrier, Thursday event-session endpoint, frozen Friday-open endpoint,
strict opposition, event-session dominance, Friday attempt, counter-gap-fade
side, and same-Friday lifecycle are jointly load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-18_xng_post_thursday_countergap_fade_source_approval.md`
authorize exactly one card, deterministic ID and magic allocation, one branch-
only non-live build, strict Q01 validation, one `RISK_FIXED` backtest setfile,
and one paced target-only Q02 enqueue only below the tester and host-CPU
ceilings.

They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; correlation claims; and correlation
waivers. Q09 alone may establish realized correlation with the certified book.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
absent strict opposition or event-session dominance, wrong fade side, failed
reconciliation, current-price leakage beyond Friday open, late or repeated
entry, wrong Friday lifecycle, nondeterminism, invalid risk mode, or an
unusable standard-Thursday proxy.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-18 | bounded composite source extraction | G0 | APPROVED_SOURCE |
