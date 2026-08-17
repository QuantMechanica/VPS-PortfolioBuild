---
source_id: EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026
title: Standard-Wednesday WTI event-session-dominant post-event counter-gap fade
publisher: U.S. Energy Information Administration / Wiley Trading / International Review of Financial Analysis
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-18_wti_post_wednesday_countergap_fade_source_approval.md
approval_commit: pending
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-18
created: 2026-08-18
created_by: Research+Development
strategy_ids:
  - EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026_S01
parent_sources:
  - EIA-WTI-WPSR-INTRADAY-2026
  - SRC03
  - YANG-COMM-REVERSAL-2017
---

# Standard-Wednesday WTI Event-Session-Dominant Counter-Gap Source Packet

## Source Identity And Complete-Read Boundary

This bounded packet joins three governed source lineages. Their complete local
records, including the Williams bounded source text, were read before this
packet was approved:

1. The U.S. Energy Information Administration, *Weekly Petroleum Status
   Report* and release schedule, through
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`. The packet
   supplies the ordinary Wednesday petroleum-information clock and its
   holiday-shift caveat. It does not define a trade.
2. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through the complete local record at
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded page-15
   through page-30 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`. Williams separates
   prior-close-to-open public flow from open-to-close professional flow and
   treats divergence between price-flow segments as potentially informative.
   He does not test WTI, the EIA clock, or this cross-boundary rule.
3. Yurun Yang, Ahmet Goncu, and Athanasios A. Pantelous (2018), "Momentum and
   reversal strategies in Chinese commodity futures markets,"
   *International Review of Financial Analysis* 60, 177-196, DOI
   `10.1016/j.irfa.2018.09.012`, through
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`. It supplies
   broad fixed-horizon commodity-reversal lineage. The repository record is
   not a complete-paper receipt, the evidence is not WTI-specific, and it
   does not define close/open endpoints or a one-session horizon.

The EIA parent packet records that fresh generic-page retrieval was
`DEFERRED:SOURCE_POLICY`. This packet imports no new webpage text and does not
retry through a browser, proxy, cache, authentication, or alternate reader.

No source tests the exact conjunction below, a Darwinex continuous CFD, the
native or uniform `+1` D1-label convention, a frozen Thursday-open endpoint,
one-D1 ownership, fixed cash risk, or an ATR stop. No source performance,
coefficient, significance, density, cost, drawdown, WTI-only efficacy, CFD
equivalence, decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026_S01` is one predeclared direct-WTI
falsification package:

- exact carrier `XTIUSD.DWX`, D1, one position on magic slot 0;
- decide only on the first executable broker-Thursday tick, no later than 180
  minutes after the executable D1 opening boundary;
- normalize D1 labels only by the governed same-day or one uniform `+1`
  calendar-day energy convention;
- require current normalized Thursday plus exact immediately completed
  Wednesday, Tuesday, and Monday sessions, with no shifted or missing-session
  substitute;
- persist the broker-Thursday `yyyymmdd` attempt before history, signal, news,
  spread, quote, ATR, sizing, or order gates and never retry it;
- compute the completed Wednesday open-to-close event-session log flow and
  the frozen Wednesday-close-to-current-Thursday-open log gap;
- require both components finite, nonzero, and strictly opposed;
- require strict event-session dominance, so the counter-gap has retraced but
  has not erased the completed Wednesday displacement;
- reconcile their sum to the exact Wednesday-open-to-Thursday-open path;
- fade only the counter-gap by trading in the still-dominant event-session
  sign at the first executable Thursday tick;
- close at the first later D1 boundary, ordinarily Friday open, with framework
  Friday close at broker hour 21 and a three-calendar-day stale guard;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
  and
- use no inventory value, forecast, external feed, magnitude threshold,
  volatility gate, moving line, oscillator, breakout, retry, scale-in, grid,
  martingale, hedge, or pyramid.

The ordinary-Wednesday clock is a price-only event proxy. Rejecting broken
Monday-Tuesday-Wednesday sequences avoids inferred holiday repair, but native
D1 prices cannot prove that every accepted Wednesday used the ordinary EIA
release schedule. That residual classification risk is a Q02 kill condition.

The Thursday D1 opening price is frozen at the bar boundary and is the only
current-bar field admitted. Thursday high, low, close, volume, later ticks,
and every post-open price are forbidden from the signal.

## Exact Signal Contract

At the first executable broker-Thursday tick following the exact completed
Wednesday:

```text
event_session_flow = ln(WednesdayClose / WednesdayOpen)
post_event_gap      = ln(ThursdayOpen / WednesdayClose)
confirmed_path      = ln(ThursdayOpen / WednesdayOpen)
total_flow          = event_session_flow + post_event_gap

require event_session_flow * post_event_gap < 0
require abs(event_session_flow) > abs(post_event_gap)
require abs(total_flow - confirmed_path) <= 1e-10

event_session_flow > 0 => BUY XTIUSD.DWX
event_session_flow < 0 => SELL XTIUSD.DWX
otherwise              => consume Thursday flat
```

All signal information is fixed at or before the Thursday opening boundary.
Component agreement, exact zero, equal magnitude, counter-gap dominance,
invalid arithmetic, a broken calendar sequence, or failed reconciliation
consumes Thursday without a trade. Magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage, a
  complete OWNER-supplied Tier-A Williams extraction, and a named
  peer-reviewed commodity-reversal publication support the separate source
  objects. The Yang local record is not a complete-paper receipt, and the
  untested conjunction and horizon mismatch are explicit.
- R2 `PASS`: weekday identity, one uniform label convention, frozen opening
  endpoint, strict opposition, event-session dominance, reconciliation,
  counter-gap-fade side, durable attempt, grace, risk, stop, spread, and exit
  are deterministic and locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC plus
  native MT5 calendar and execution state supply every runtime input. The
  standard-Wednesday proxy and D1 labels remain falsifiable.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,540 EA-registry rows and 625
root cards. It found no exact identity and no fuzzy match above its threshold.
Manual family review fixes the material boundaries:

- `QM5_41050_wti-postwed-gap-agree` uses the identical cross-boundary
  endpoints but admits only strict same-sign agreement and follows the common
  sign. This package admits only strict opposition plus event-session
  dominance and fades the later counter-gap. Eligible states are disjoint.
- `QM5_41041_wti-wed-flow-fade` compares Tuesday-close-to-Wednesday-open with
  Wednesday-open-to-close, so both components are complete by Wednesday
  close. This package starts with the event session and requires the later
  Wednesday-close-to-frozen-Thursday-open counter-gap.
- `QM5_41049_wti-wed-overnight-dom` partitions opposed components inside
  Wednesday, requires pre-event overnight dominance, and follows that total.
  This package requires event-session dominance across the later
  Wednesday/Thursday boundary and trades against the counter-gap.
- `QM5_41042_wti-wed-flow-agree` requires agreement between the pre-event
  overnight gap and Wednesday session; it never reads Thursday open.
- `QM5_12590_eia-wti-wpsr-fade` requires a stretched large-range event bar,
  tail location, SMA distance, and a multiday lifecycle. This package has no
  magnitude, range, body, tail, or mean gate and exits at the next D1 boundary.
- `QM5_20133` and `QM5_20134` use exact M30 release/pullback or reclaim
  sequences before the completed D1/post-open state exists.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback, not a symmetric WTI event-time counter-gap rule.

Manual verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.
The carrier, event-session endpoint, post-event opening-gap endpoint, strict
opposition, event-session dominance, Thursday attempt, and next-D1 exit are
jointly load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-18_wti_post_wednesday_countergap_fade_source_approval.md`
authorize exactly one card, deterministic ID and magic allocation, one
branch-only non-live build, strict Q01 validation, one `RISK_FIXED` backtest
setfile, and one paced target-only Q02 enqueue if capacity permits.

They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q09 alone
may establish realized correlation with the certified book.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
absent strict opposition or event-session dominance, wrong counter-gap-fade
side, failed reconciliation, current-price leakage beyond frozen Thursday
open, late or repeated entry, wrong lifecycle, nondeterminism, invalid risk
mode, or an economically unusable standard-Wednesday proxy.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-18 | bounded composite source extraction | G0 | APPROVED_SOURCE |
