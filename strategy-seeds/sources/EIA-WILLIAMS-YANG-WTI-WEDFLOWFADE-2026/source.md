---
source_id: EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026
title: Standard-Wednesday WTI session-dominant price-flow fade
publisher: U.S. Energy Information Administration / Wiley Trading / International Review of Financial Analysis
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_wti_wednesday_flow_fade_source_approval.md
strategy_ids:
  - EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026_S01
cards_extracted:
  - wti-wed-flow-fade
parent_sources:
  - EIA-WTI-WPSR-INTRADAY-2026
  - SRC03
  - YANG-COMM-REVERSAL-2017
---

# Standard-Wednesday WTI Session-Dominant Flow-Fade Source Packet

## Source Identity And Read Boundary

This packet joins three governed primary-source lineages whose repository
records were read completely before card extraction:

1. The U.S. Energy Information Administration, *Weekly Petroleum Status
   Report* and release schedule, through the approved packet
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`. It establishes
   a recurring crude-oil information clock whose ordinary release is Wednesday
   and whose holiday weeks can shift. It supplies event identity only.
2. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through the OWNER-supplied Tier-A record
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded page-15-to-30
   text at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`. Williams defines
   prior-close-to-open and open-to-close price-flow objects, accumulates them
   separately, and discusses their disagreement. He does not test WTI or this
   calendar rule.
3. Yurun Yang, Ahmet Goncu, and Athanasios A. Pantelous (2018), "Momentum and
   reversal strategies in Chinese commodity futures markets," *International
   Review of Financial Analysis* 60, 177-196, DOI
   `10.1016/j.irfa.2018.09.012`, through the governed extraction
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`. It supplies broad
   fixed-horizon commodity-reversal lineage. The local packet is not a
   complete-paper receipt, the universe is Chinese commodity futures, and it
   supplies no WTI-specific or price-flow-decomposition result.

The existing EIA packet records that fresh generic-URL retrieval was
`DEFERRED:SOURCE_POLICY`; this packet imports no new webpage text and does not
retry through a browser, proxy, cache, authentication, or alternate reader.
The official event identity, the Williams decomposition, and the broad
commodity-reversal lineage are the entire source claim.

No source tests the exact conjunction below, Darwinex continuous CFDs, the
same-day or uniform `+1` energy-label convention, a Thursday market entry,
one-D1 hold, fixed cash risk, or an ATR stop. No source return, coefficient,
significance, trade count, cost, drawdown, WTI-only efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026_S01` is one predeclared direct-WTI
package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- decide only on the first executable tick of broker Thursday, within 180
  minutes of the executable D1 open;
- normalize D1 labels only by the governed same-day or one uniform `+1`
  calendar-day energy convention;
- require the current normalized Thursday plus exact completed Wednesday,
  Tuesday, and Monday sessions; never substitute a missing session;
- persist the exact broker-Thursday attempt before every fallible gate;
- compute the completed Wednesday close-to-open log return from Tuesday close
  to Wednesday open and the completed Wednesday open-to-close log return;
- require strict sign opposition and strict session dominance;
- reconcile their sum to the exact Tuesday-close-to-Wednesday-close return;
- fade that completed session-dominant Wednesday return at Thursday open;
- close on the first later D1 boundary, ordinarily Friday open, with framework
  Friday close at broker hour 21 and a three-calendar-day stale guard;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
  and
- use no external runtime data, magnitude threshold, volatility signal gate,
  moving line, oscillator, breakout, retry, scale-in, grid, martingale, or
  pyramid.

The standard-Wednesday clock is a deterministic price-only proxy. A holiday
week with a missing Monday, Tuesday, or Wednesday D1 session is rejected, but
the EA does not import the official release calendar and cannot prove that
every otherwise complete Wednesday was an unshifted release. Residual event-
clock misclassification is a declared Q02 kill risk.

## Exact Signal Contract

For the exact completed Wednesday immediately before the Thursday decision:

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow < 0
require abs(session_flow) > abs(overnight_flow)
require total_flow reconciles to day_return within 1e-10

total_flow > 0 => SELL XTIUSD.DWX
total_flow < 0 => BUY XTIUSD.DWX
otherwise      => consume Thursday flat
```

All signal endpoints are completed before the Thursday entry. Exact zero,
component agreement, equal absolute magnitude, invalid arithmetic, a broken
calendar sequence, or failed reconciliation consumes the Thursday without a
trade. Signal magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: an approved official EIA event
  packet, a complete OWNER-supplied Tier-A Williams extraction, and a named
  peer-reviewed commodity-reversal publication support the separate source
  objects. The Yang local record is not a full-paper receipt and no source
  validates the conjunction; both limitations are explicit.
- R2 `PASS`: exact weekdays, normalized labels, completed endpoints, strict
  opposition, strict session dominance, reconciliation, fade direction,
  attempt state, entry grace, risk, stop, spread, and next-boundary exit are
  deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native MT5 execution state
  supply every runtime input. The direct-WTI session offset is governed by
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native timestamps, calendar, OHLC, logarithms, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,528 EA-registry rows and 625 card
files. It returned `CLEAN` with no exact or fuzzy match. Manual family review
returned
`CLEAN_WTI_STANDARD_WEDNESDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_FAMILY_REVIEW`:

- `QM5_12590_eia-wti-wpsr-fade` requires a stretched, large-range, directional
  D1 event bar with tail-location and SMA-distance gates, then holds up to four
  days. This packet uses no range, body, tail, mean, or magnitude threshold;
  it requires internal Wednesday overnight/session opposition and exits at the
  next D1 boundary.
- `QM5_12579_eia-wti-aftershock` follows a large D1 event move rather than
  fading a session-dominant opposed-flow state.
- `QM5_20133_wti-wpsr-pb` and `QM5_20134_wti-wpsr-fail` use exact M30 release,
  pullback/reclaim, range, target, and same-session sequences. This packet uses
  only completed D1 close/open endpoints and enters the next day.
- `QM5_12988_xti-eia-inventory-momentum` requires two same-direction event
  reactions plus moving-average and channel confirmation. This packet has one
  completed Wednesday, opposed components, and a contrarian one-D1 hold.
- `QM5_41029`, `QM5_41032`, and `QM5_41033` aggregate a full completed
  Monday-through-Friday week, enter the next Monday, and close Friday. This
  packet isolates one Wednesday, decides Thursday, fades only a strict
  session-dominant disagreement, and closes at the next D1 boundary.
- `QM5_41040_xauxag-wflow-fade` is a synchronized two-metal relative basket
  formed over a full week. This packet is one direct energy carrier, one
  event-clock session, and no cross-symbol subtraction or hedge.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a symmetric structural event-time flow rule.

The exact standard-Wednesday session, two information-time components, strict
opposition, strict session dominance, completed-day fade, Thursday decision,
and next-D1 exit are jointly load-bearing. A weak result may not be rescued by
adding a magnitude, volatility, SMA, range, tail, inventory, or season filter;
accepting agreement; changing the weekday; or extending the hold.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_wti_wednesday_flow_fade_source_approval.md` authorize
exactly one card, deterministic ID and magic allocation, one branch-only
non-live build, strict Q01 validation, one `RISK_FIXED` backtest setfile, and
one paced target-only Q02 enqueue if the tester ceiling permits.

They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q09 alone
may establish realized correlation with the certified book.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong weekday identity or endpoints,
component agreement, absent session dominance, wrong fade direction, failed
reconciliation, current-bar leakage, late or repeated entry, wrong lifecycle,
nondeterminism, invalid risk mode, or evidence that the calendar proxy is not
economically usable.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |

