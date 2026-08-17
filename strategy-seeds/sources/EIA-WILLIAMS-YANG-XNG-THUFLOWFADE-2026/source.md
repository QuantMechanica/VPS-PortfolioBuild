---
source_id: EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026
title: Standard-Thursday XNG session-dominant price-flow fade
publisher: U.S. Energy Information Administration / Wiley Trading / International Review of Financial Analysis
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_xng_thursday_flow_fade_source_approval.md
approval_commit: fcccf5407
strategy_ids:
  - EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026_S01
cards_extracted:
  - strategy-seeds/cards/approved/QM5_41044_xng-thu-flow-fade_card.md
parent_sources:
  - EIA-XNG-STORAGE-AFTERSHOCK-2026
  - SRC03
  - YANG-COMM-REVERSAL-2017
---

# Standard-Thursday XNG Session-Dominant Flow-Fade Source Packet

## Source Identity And Read Boundary

This packet joins three governed source lineages whose bounded local records
were read completely before extraction:

1. The U.S. Energy Information Administration, *Weekly Natural Gas Storage
   Report* and official release schedule, through
   `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`. The
   approved packet establishes a recurring natural-gas information clock whose
   ordinary release is Thursday at 10:30 a.m. eastern time and whose holiday
   weeks can shift. It supplies event identity only.
2. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through `strategy-seeds/sources/SRC03/source.md` and the complete
   bounded page-15-to-30 extraction at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`. Williams separates
   prior-close-to-open and open-to-close price flows, labels the latter as
   professional-session flow, and describes studying their separate behavior.
   He does not test natural gas, a Thursday storage rule, strict opposition,
   session dominance, or this fade.
3. Yurun Yang, Ahmet Goncu, and Athanasios A. Pantelous (2018), "Momentum and
   reversal strategies in Chinese commodity futures markets,"
   *International Review of Financial Analysis* 60, 177-196, DOI
   `10.1016/j.irfa.2018.09.012`, through the governed partial extraction at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`. It supplies
   broad fixed-horizon commodity-reversal lineage. The local record is not a
   complete-paper receipt, its universe is not XNG, and its horizons do not
   establish this one-D1 rule.

The EIA packet records that fresh generic-URL retrieval was
`DEFERRED:SOURCE_POLICY`; no alternate browser, proxy, cache, authentication,
or policy bypass was used. This packet imports no changed schedule claim.

No source tests the exact conjunction below, a Darwinex continuous CFD, the
same-day or uniform `+1` energy-label convention, Friday entry, weekend hold,
one-D1 lifecycle, fixed cash risk, or ATR stop. No source return, coefficient,
significance, density, cost, drawdown, XNG-only efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026_S01` is one predeclared direct-XNG
package:

- exact carrier `XNGUSD.DWX`, D1, magic slot 0;
- decide only on the first executable broker-Friday tick, within 180 minutes
  of the executable D1 open;
- normalize D1 labels only by the governed same-day or one uniform `+1`
  calendar-day energy convention;
- require current normalized Friday plus exact immediately completed Thursday,
  Wednesday, and Tuesday sessions, with no missing-session substitute;
- persist the broker-Friday attempt before every fallible gate;
- compute Thursday close-to-open flow from Wednesday close to Thursday open
  and Thursday open-to-close session flow from completed prices;
- require both nonzero components to have strictly opposite signs and require
  the absolute session component to exceed the absolute overnight component;
- reconcile their sum to the Wednesday-close-to-Thursday-close log return;
- fade that completed Thursday total at Friday open;
- close on the first later D1 boundary, ordinarily Monday open, with framework
  Friday close disabled and a four-calendar-day stale guard;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target; and
- use no external runtime data, magnitude threshold, volatility signal gate,
  moving line, oscillator, range, tail, breakout, storage value, retry,
  scale-in, grid, martingale, or pyramid.

The standard-Thursday clock is a price-only event proxy. A holiday week with a
missing Tuesday, Wednesday, or Thursday D1 session is rejected, but without an
external release calendar the EA cannot prove every complete Thursday was an
unshifted storage release. Residual event-clock misclassification and weekend
gap exposure are declared Q02 kill risks.

## Exact Signal Contract

For the completed Thursday immediately before Friday:

```text
overnight_flow = ln(ThursdayOpen / WednesdayClose)
session_flow   = ln(ThursdayClose / ThursdayOpen)
day_return     = ln(ThursdayClose / WednesdayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow < 0
require abs(session_flow) > abs(overnight_flow)
require total_flow reconciles to day_return within 1e-10

total_flow > 0 => SELL XNGUSD.DWX
total_flow < 0 => BUY XNGUSD.DWX
otherwise      => consume Friday flat
```

All endpoints are completed before entry. Agreement, exact zero, equal
magnitude, absent session dominance, invalid arithmetic, a broken calendar
sequence, or failed reconciliation consumes Friday without a trade. Signal
magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, a complete OWNER-supplied Tier-A Williams extraction, and a
  peer-reviewed final-publication commodity-reversal lineage whose local
  record is partial and whose universe is not XNG. No source tests this exact
  conjunction; the limitation is explicit.
- R2 `PASS`: exact weekdays, label normalization, completed endpoints, strict
  opposition, strict session dominance, reconciliation, contrarian side,
  attempt state, grace, risk, stop, spread, and next-boundary exit are
  deterministic and locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC plus
  native MT5 calendar and execution state supply every runtime input. The
  energy-label convention remains an explicit carrier risk.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Boundary

The canonical checker scanned 4,531 EA-registry rows and 625 root card files
and returned `CLEAN` without an exact or fuzzy match. Manual review separates
the material relatives:

- `QM5_41043_xng-thu-flow-agree` requires strict same-sign Thursday components
  and follows the completed total. This package requires opposition plus
  session dominance and fades the total.
- `QM5_41041_wti-wed-flow-fade` uses WTI's Wednesday petroleum clock, enters
  Thursday, and normally exits Friday. This package uses XNG's Thursday
  storage clock, enters Friday, and owns the next D1 interval across a weekend.
- `QM5_12819_xng-thu-fade` is an unconditional Thursday short. This package
  waits for a completed Thursday, can trade either side, and requires the
  opposed-flow state.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` trade M30 release impulse,
  reclaim, or live-breakout objects. This package never enters during the
  release session and uses only completed D1 flow components.
- `QM5_41037` and `QM5_41038` form over complete XNG broker months and hold to
  the following month. This package forms from one event-clock session and
  exits at the first later D1 boundary.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not an event-time symmetric reversal rule.

Manual verdict:
`CLEAN_XNG_STANDARD_THURSDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.
The XNG carrier, Thursday storage clock, strict opposition, session dominance,
completed-total fade, Friday decision, and next-D1 exit are jointly
load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_xng_thursday_flow_fade_source_approval.md` authorize
exactly one card, deterministic ID and magic allocation, one branch-only
non-live build, strict Q01 validation, one `RISK_FIXED` backtest setfile, and
one paced target-only Q02 enqueue if capacity permits.

They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q09 alone
may establish realized correlation with the certified book.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
component agreement, absent strict session dominance, wrong contrarian side,
failed reconciliation, current-bar leakage, late or repeated entry, wrong
lifecycle, nondeterminism, invalid risk mode, or an economically unusable
calendar proxy.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-17 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic EA, fixed-risk set, and Q01 evidence | Q01 | PASS |
