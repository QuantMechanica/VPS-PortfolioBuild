---
source_id: EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026
title: Standard-Wednesday WTI event-session and post-event-gap continuation
publisher: U.S. Energy Information Administration / Wiley Trading / Journal of Financial Economics
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-17_wti_post_wednesday_gap_agreement_source_approval.md
approval_commit: 8ee045854
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-17
created: 2026-08-17
created_by: Research+Development
strategy_ids:
  - EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026_S01
cards_extracted:
  - QM5_41050_wti-postwed-gap-agree
parent_sources:
  - EIA-WTI-WPSR-INTRADAY-2026
  - SRC03
  - MOP-TSMOM-2012
---

# Standard-Wednesday WTI Event-Session/Post-Event-Gap Source Packet

## Source Identity And Complete-Read Boundary

This packet joins three already governed source lineages. Their bounded local
records were read completely before this extraction:

1. The U.S. Energy Information Administration, *Weekly Petroleum Status
   Report* and release schedule, through
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`. The official
   packet establishes the ordinary Wednesday crude-oil information clock and
   warns that holiday releases can shift. It supplies event identity only.
2. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through the complete local record at
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   page-15-to-30 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`. Williams separates
   prior-close-to-open public flow from open-to-close professional flow,
   accumulates them independently, and treats their divergence or crossing as
   potentially informative. He does not test WTI, EIA Wednesdays, or the
   cross-boundary agreement rule below.
3. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, through the complete-paper receipt and
   durable retrieval hash in
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The paper supplies
   peer-reviewed own-return continuation lineage across liquid futures and
   explicitly includes WTI. Its tested horizons are materially longer than
   one D1 interval.

The EIA packet records that fresh generic retrieval of its canonical pages
was `DEFERRED:SOURCE_POLICY`. No alternate browser, cache, proxy,
authentication, or access-control workaround was used, and no changed
schedule claim is imported.

No source tests the exact conjunction below, a Darwinex continuous CFD, the
same-day or uniform `+1` energy-label convention, a current-Thursday-open
endpoint, a one-D1 hold, fixed cash risk, or an ATR stop. No source return,
coefficient, significance, density, cost, drawdown, WTI-only efficacy, CFD
equivalence, decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026_S01` is one predeclared direct-WTI
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
- compute the completed Wednesday open-to-close log flow and the frozen
  current-Thursday-open relative to Wednesday close;
- require both components finite, nonzero, and strictly equal in sign;
- reconcile their sum to the exact Wednesday-open-to-Thursday-open return;
- follow that confirmed sign at the first executable Thursday tick;
- close at the first later D1 boundary, ordinarily Friday open, with framework
  Friday close at broker hour 21 and a three-calendar-day stale guard;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
  and
- use no inventory value, forecast, external feed, magnitude threshold,
  volatility gate, moving line, oscillator, breakout, retry, scale-in, grid,
  martingale, hedge, or pyramid.

The ordinary-Wednesday clock is a price-only event proxy. Rejecting broken
Monday-Tuesday-Wednesday sequences avoids inferred holiday repair, but native
D1 prices cannot prove that every accepted Wednesday used the ordinary EIA
release schedule. That residual classification risk is a Q02 kill condition.

The Thursday D1 bar's opening price is frozen at the bar boundary and is the
only current-bar field admitted. Its high, low, close, volume, ticks after the
first executable decision, and any post-open price never enter the signal.

## Exact Signal Contract

At the first executable broker-Thursday tick following the exact completed
Wednesday:

```text
event_session_flow = ln(WednesdayClose / WednesdayOpen)
post_event_gap      = ln(ThursdayOpen / WednesdayClose)
confirmed_path      = ln(ThursdayOpen / WednesdayOpen)
total_flow          = event_session_flow + post_event_gap

require event_session_flow * post_event_gap > 0
require abs(total_flow - confirmed_path) <= 1e-10

total_flow > 0 => BUY XTIUSD.DWX
total_flow < 0 => SELL XTIUSD.DWX
otherwise      => consume Thursday flat
```

All signal information is fixed at or before the Thursday opening boundary.
Opposition, exact zero, invalid arithmetic, a broken calendar sequence, or
failed reconciliation consumes Thursday without a trade. Magnitude never
changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage, a
  complete OWNER-supplied Tier-A Williams extraction, and a complete-paper
  receipt for a peer-reviewed JFE continuation study that includes WTI. The
  untested conjunction and horizon mismatch are explicit.
- R2 `PASS`: weekday identity, one uniform label convention, frozen opening
  endpoint, strict agreement, reconciliation, continuation side, durable
  attempt, grace, risk, stop, spread, and exit are deterministic and locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC plus
  native MT5 calendar and execution state supply every runtime input. The
  standard-Wednesday proxy and D1 labels remain falsifiable.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,537 EA-registry rows and 625
root cards. It found no exact identity and no fuzzy match above its threshold.
Manual family review fixes the material boundaries:

- `QM5_41042_wti-wed-flow-agree` requires strict agreement between
  Tuesday-close-to-Wednesday-open and Wednesday-open-to-Wednesday-close. This
  package shifts the first endpoint forward: the completed Wednesday event
  session must agree with the later Wednesday-close-to-Thursday-open gap.
- `QM5_41049_wti-wed-overnight-dom` partitions opposed components inside the
  completed Wednesday and follows only strict overnight dominance. This
  package requires agreement across the Wednesday/Thursday boundary and uses
  no dominance test.
- `QM5_41041_wti-wed-flow-fade` partitions opposed components inside the
  completed Wednesday and fades strict session dominance. This package
  requires sign agreement, follows it, and admits no opposition state.
- `QM5_41043_xng-thu-flow-agree` decomposes the completed Thursday natural-gas
  session and enters Friday. This package uses the WTI EIA Wednesday session,
  the immediately following opening gap, and a Thursday entry.
- `QM5_12579_eia-wti-aftershock` follows only a large completed D1 event bar.
  This package has no magnitude, range, body, tail, mean, or breakout gate;
  the next opening gap's sign confirmation is load-bearing.
- `QM5_12988_xti-eia-inventory-momentum` requires two aligned event reactions
  plus moving-average and channel confirmation. This package uses one event
  session, one immediately following gap, and no slow or range indicator.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback, not a symmetric WTI event-flow continuation rule.

Manual verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.
The carrier, event-session endpoint, post-event opening-gap endpoint, strict
agreement, Thursday attempt, and next-D1 exit are jointly load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_wti_post_wednesday_gap_agreement_source_approval.md`
authorize exactly one card, deterministic ID and magic allocation, one
branch-only non-live build, strict Q01 validation, one `RISK_FIXED` backtest
setfile, and one paced target-only Q02 enqueue if capacity permits.

They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q09 alone
may establish realized correlation with the certified book.

Expected cadence is approximately twelve to twenty-six completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
absent strict agreement, wrong continuation side, failed reconciliation,
current-price leakage beyond Thursday open, late or repeated entry, wrong
lifecycle, nondeterminism, invalid risk mode, or an economically unusable
standard-Wednesday proxy.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
