---
source_id: EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026
title: Standard-Thursday XNG price-flow agreement continuation
publisher: U.S. Energy Information Administration / Wiley Trading / Journal of Financial Economics
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_xng_thursday_flow_agreement_source_approval.md
approval_commit: 0dcf4d10a
strategy_ids:
  - EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026_S01
cards_extracted:
  - strategy-seeds/cards/approved/QM5_41043_xng-thu-flow-agree_card.md
parent_sources:
  - EIA-XNG-STORAGE-AFTERSHOCK-2026
  - SRC03
  - MOP-TSMOM-2012
---

# Standard-Thursday XNG Flow-Agreement Source Packet

## Source Identity And Read Boundary

This packet joins three governed primary-source lineages whose bounded local
records were read completely before extraction:

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
   prior-close-to-open and open-to-close price flows and describes accumulating
   them independently. He does not test natural gas, a Thursday storage rule,
   strict sign agreement, or this signal.
3. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, through the complete-paper receipt at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It supplies peer-reviewed
   own-return continuation lineage across liquid futures and explicitly
   includes natural gas. Its tested horizons are materially longer than one
   D1 session.

The EIA packet records that fresh generic-URL retrieval was
`DEFERRED:SOURCE_POLICY`; no alternate browser, proxy, cache, authentication,
or policy bypass was used. This packet imports no changed schedule claim.

No source tests the exact conjunction below, a Darwinex continuous CFD, the
same-day or uniform `+1` energy-label convention, Friday entry, weekend hold,
one-D1 lifecycle, fixed cash risk, or ATR stop. No source return, coefficient,
significance, trade count, cost, drawdown, XNG-only efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026_S01` is one predeclared direct-XNG
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
- require both nonzero components to have the same strict sign;
- reconcile their sum to the Wednesday-close-to-Thursday-close log return;
- follow that agreed completed Thursday direction at Friday open;
- close on the first later D1 boundary, ordinarily Monday open, with framework
  Friday close disabled and a four-calendar-day stale guard;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target; and
- use no external runtime data, magnitude threshold, volatility signal gate,
  moving line, oscillator, breakout, storage value, retry, scale-in, grid,
  martingale, or pyramid.

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

require overnight_flow * session_flow > 0
require total_flow reconciles to day_return within 1e-10

total_flow > 0 => BUY XNGUSD.DWX
total_flow < 0 => SELL XNGUSD.DWX
otherwise      => consume Friday flat
```

All endpoints are completed before entry. Exact zero, component opposition,
invalid arithmetic, a broken calendar sequence, or failed reconciliation
consumes Friday without a trade. Signal magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, a complete OWNER-supplied Tier-A Williams extraction, and a
  complete-paper receipt for a peer-reviewed JFE futures-continuation study
  that includes natural gas. No source tests this exact XNG event-time
  conjunction and the JFE horizons are longer; both limitations are explicit.
- R2 `PASS`: exact weekdays, label normalization, completed endpoints, strict
  agreement, reconciliation, continuation side, attempt state, grace, risk,
  stop, spread, and next-boundary exit are deterministic and locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC plus
  native MT5 calendar and execution state supply every runtime input. The
  energy-label convention remains an explicit carrier risk.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Boundary

The canonical checker scanned 4,530 EA-registry rows and 625 flat card files.
It found no exact match and surfaced the expected weekly/monthly WTI flow-
agreement relatives for manual review:

- `QM5_41029_wti-flow-agree` aggregates an exact completed Monday-Friday WTI
  week, enters the next Monday, and holds through Friday. This package isolates
  one XNG Thursday storage-clock session, enters Friday, and exits at the next
  D1 boundary.
- `QM5_41034_wti-mflow-agree` aggregates a completed WTI broker month and holds
  to the following month. This package uses one XNG event-clock session.
- `QM5_41042_wti-wed-flow-agree` uses the analogous strict-agreement object on
  WTI's ordinary Wednesday petroleum clock, enters Thursday, and ordinarily
  exits Friday. This package has an XNG carrier, Thursday storage clock, Friday
  entry, and weekend-bearing next-D1 lifecycle; no WTI route or result transfers.
- `QM5_20163_xng-thu-trend` enters short on Thursday only under a negative
  completed 252-D1 return. This package waits for completed Thursday flow,
  enters Friday, is symmetric, and has no slow-trend state.
- `QM5_12819_xng-thu-fade` is an unconditional short entered on Thursday. This
  package enters only Friday after strict same-sign completed Thursday flow and
  follows either sign.
- `QM5_20011_xng-thu-tue` is an unconditional long Friday-to-Wednesday calendar
  carry. This package is conditional, symmetric, and exits at the first later
  D1 boundary.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` trade M30 release impulse, reclaim,
  or live breakout objects. This package uses only completed D1 flow components
  and never enters in the release session.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not an event-time continuation rule.

Manual verdict:
`CLEAN_XNG_STANDARD_THURSDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.
The exact XNG carrier, Thursday session, two component signs, strict agreement,
completed-day continuation, Friday decision, and next-D1 exit are jointly
load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_xng_thursday_flow_agreement_source_approval.md` authorize
exactly one card, deterministic ID and magic allocation, one branch-only
non-live build, strict Q01 validation, one `RISK_FIXED` backtest setfile, and
one paced target-only Q02 enqueue if capacity permits.

They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q09 alone
may establish realized correlation with the certified book.

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
component opposition, wrong continuation side, failed reconciliation, current-
bar leakage, late or repeated entry, wrong lifecycle, nondeterminism, invalid
risk mode, or an economically unusable calendar proxy.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-card | 2026-08-17 | locked card extraction and OWNER G0 authorization | G0 | APPROVED |
