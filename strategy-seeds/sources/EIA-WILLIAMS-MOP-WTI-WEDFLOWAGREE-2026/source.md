---
source_id: EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026
title: Standard-Wednesday WTI price-flow agreement continuation
publisher: U.S. Energy Information Administration / Wiley Trading / Journal of Financial Economics
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_wti_wednesday_flow_agreement_source_approval.md
approval_commit: 65df03e03
strategy_ids:
  - EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026_S01
cards_extracted:
  - wti-wed-flow-agree
parent_sources:
  - EIA-WTI-WPSR-INTRADAY-2026
  - SRC03
  - MOP-TSMOM-2012
---

# Standard-Wednesday WTI Flow-Agreement Source Packet

## Source Identity And Read Boundary

This packet joins three governed primary-source lineages whose bounded local
records were read completely before extraction:

1. The U.S. Energy Information Administration, *Weekly Petroleum Status
   Report* and release schedule, through
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`. The approved
   packet establishes a recurring crude-oil information clock whose ordinary
   release is Wednesday and whose holiday weeks can shift. It supplies event
   identity only.
2. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through `strategy-seeds/sources/SRC03/source.md` and the complete
   bounded page-15-to-30 extraction at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`. Williams separates
   prior-close-to-open and open-to-close price flows and describes accumulating
   them independently. He does not test WTI, a Wednesday rule, or this signal.
3. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, through the complete-paper receipt at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It supplies peer-reviewed
   own-return continuation lineage across liquid futures including WTI. Its
   tested horizons are materially longer than one D1 session.

The EIA packet records that fresh generic-URL retrieval was
`DEFERRED:SOURCE_POLICY`; no alternate browser, proxy, cache, authentication,
or policy bypass was used. This packet imports no changed schedule claim.

No source tests the exact conjunction below, the Darwinex continuous CFD, the
same-day or uniform `+1` energy-label convention, Thursday entry, one-D1 hold,
fixed cash risk, or ATR stop. No source return, coefficient, significance,
trade count, cost, drawdown, WTI-only efficacy, CFD equivalence, decorrelation,
or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026_S01` is one predeclared direct-WTI
package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- decide only on the first executable broker-Thursday tick, within 180 minutes
  of the executable D1 open;
- normalize D1 labels only by the governed same-day or one uniform `+1`
  calendar-day energy convention;
- require current normalized Thursday plus exact immediately completed
  Wednesday, Tuesday, and Monday sessions, with no missing-session substitute;
- persist the broker-Thursday attempt before every fallible gate;
- compute Wednesday close-to-open flow from Tuesday close to Wednesday open
  and Wednesday open-to-close session flow from completed prices;
- require both nonzero components to have the same strict sign;
- reconcile their sum to the Tuesday-close-to-Wednesday-close log return;
- follow that agreed completed Wednesday direction at Thursday open;
- close on the first later D1 boundary, ordinarily Friday open, with framework
  Friday close at broker hour 21 and a three-calendar-day stale guard;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target; and
- use no external runtime data, magnitude threshold, volatility signal gate,
  moving line, oscillator, breakout, retry, scale-in, grid, martingale, or
  pyramid.

The standard-Wednesday clock is a price-only event proxy. A holiday week with
a missing Monday, Tuesday, or Wednesday D1 session is rejected, but without an
external release calendar the EA cannot prove every complete Wednesday was an
unshifted release. Residual event-clock misclassification is a declared Q02
kill risk.

## Exact Signal Contract

For the completed Wednesday immediately before Thursday:

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow > 0
require total_flow reconciles to day_return within 1e-10

total_flow > 0 => BUY XTIUSD.DWX
total_flow < 0 => SELL XTIUSD.DWX
otherwise      => consume Thursday flat
```

All endpoints are completed before entry. Exact zero, component opposition,
invalid arithmetic, a broken calendar sequence, or failed reconciliation
consumes Thursday without a trade. Signal magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, a complete OWNER-supplied Tier-A Williams extraction, and a
  complete-paper receipt for a peer-reviewed JFE futures-continuation study.
  Neither Williams nor MOP tests this exact WTI event-time conjunction, and
  MOP's tested horizons are longer; both limitations are explicit.
- R2 `PASS`: exact weekdays, label normalization, completed endpoints, strict
  agreement, reconciliation, continuation side, attempt state, grace, risk,
  stop, spread, and next-boundary exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC plus native MT5 calendar and
  execution state supply every runtime input.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Boundary

The canonical checker scanned 4,529 EA-registry rows and 625 flat card files.
It found no exact match and surfaced the expected flow-agreement family for
manual review:

- `QM5_41029_wti-flow-agree` aggregates an exact completed Monday-Friday week,
  enters the next Monday, and holds through Friday. This package isolates one
  standard Wednesday, enters Thursday, and exits at the next D1 boundary.
- `QM5_41034_wti-mflow-agree` aggregates a completed broker month, enters at a
  new month, and holds to the following month. This package uses one event-clock
  session and a one-D1 lifecycle.
- `QM5_41041_wti-wed-flow-fade` uses the same Wednesday clock but requires
  strict component opposition plus session dominance and fades the completed
  total. This package requires strict agreement and follows the total.
- `QM5_20154_wti-wed-trend` is long-only and requires a positive completed
  252-D1 state. This package is symmetric, has no slow trend state, and reads
  the internal completed-Wednesday flow decomposition.
- `QM5_41024_wti-1wed-mom1` trades only the first genuine Wednesday of a month
  from the prior completed-month sign. This package evaluates every standard
  Thursday from the immediately completed Wednesday and no monthly return.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not an event-time continuation rule.

Manual verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.
The exact Wednesday session, two component signs, strict agreement, completed-
day continuation, Thursday decision, and next-D1 exit are jointly load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_wti_wednesday_flow_agreement_source_approval.md`
authorize exactly one card, deterministic ID and magic allocation, one
branch-only non-live build, strict Q01 validation, one `RISK_FIXED` backtest
setfile, and one paced target-only Q02 enqueue if capacity permits.

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
