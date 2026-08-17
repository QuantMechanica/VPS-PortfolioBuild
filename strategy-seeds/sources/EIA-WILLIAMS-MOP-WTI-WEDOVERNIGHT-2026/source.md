---
source_id: EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026
title: Standard-Wednesday WTI overnight-dominant opposed-flow continuation
publisher: U.S. Energy Information Administration / Wiley Trading / Journal of Financial Economics
source_type: official_event_practitioner_book_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-17_wti_wednesday_overnight_dominance_source_approval.md
approval_commit: PENDING_SOURCE_APPROVAL_COMMIT
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-17
created: 2026-08-17
created_by: Research+Development
strategy_ids:
  - EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026_S01
cards_extracted: []
parent_sources:
  - EIA-WTI-WPSR-INTRADAY-2026
  - SRC03
  - MOP-TSMOM-2012
---

# Standard-Wednesday WTI Overnight-Dominant Flow Source Packet

## Source Identity And Complete-Read Boundary

This packet joins three already governed source lineages. Their bounded local
records were read completely before this extraction:

1. The U.S. Energy Information Administration, *Weekly Petroleum Status
   Report* and release schedule, through
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`. The official
   packet establishes the ordinary Wednesday crude-oil information clock and
   warns that holiday releases can shift. It supplies event identity only.
2. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading, through `strategy-seeds/sources/SRC03/source.md` and the complete
   bounded page-15-to-30 extraction at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`. Williams separates
   prior-close-to-open public flow from open-to-close professional flow,
   accumulates them independently, and treats their divergence or crossing as
   potentially informative. He does not test WTI, an event Wednesday, strict
   one-session dominance, or the rule below.
3. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, through the complete-paper receipt and
   durable retrieval hash in
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The paper supplies
   peer-reviewed own-return continuation lineage across liquid futures and
   explicitly includes WTI. Its tested horizons are materially longer than
   one D1 interval.

The EIA packet records that fresh generic retrieval of its canonical pages was
`DEFERRED:SOURCE_POLICY`. No alternate browser, cache, proxy, authentication,
or access-control workaround was used, and no changed schedule claim is
imported.

No source tests the exact conjunction below, a Darwinex continuous CFD, the
same-day or uniform `+1` energy-label convention, a Thursday entry, a one-D1
hold, fixed cash risk, or an ATR stop. No source return, coefficient,
significance, density, cost, drawdown, WTI-only efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Bounded Mechanization

`EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026_S01` is one predeclared direct-WTI
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
- compute Wednesday close-to-open flow from Tuesday close to Wednesday open
  and Wednesday open-to-close flow from completed prices;
- require both components to be finite, nonzero, and strictly opposite;
- require the absolute overnight component to be strictly greater than the
  absolute session component, so the reconciled completed-day return retains
  the overnight sign;
- follow the reconciled completed Wednesday direction at Thursday open;
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
release schedule. That residual event-clock classification risk is a Q02 kill
condition.

## Exact Signal Contract

For the completed Wednesday immediately before broker Thursday:

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow < 0
require abs(overnight_flow) > abs(session_flow)
require abs(total_flow - day_return) <= 1e-10

total_flow > 0 => BUY XTIUSD.DWX
total_flow < 0 => SELL XTIUSD.DWX
otherwise      => consume Thursday flat
```

All endpoints are completed before entry. Agreement, exact zero, equal
magnitudes, session dominance, invalid arithmetic, a broken calendar sequence,
or failed reconciliation consumes Thursday without a trade. Magnitude never
changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage, a
  complete OWNER-supplied Tier-A Williams extraction, and a complete-paper
  receipt for a peer-reviewed JFE continuation study that includes WTI. The
  untested conjunction and horizon mismatch are explicit.
- R2 `PASS`: weekday identity, one uniform label convention, completed
  endpoints, strict opposition, strict overnight dominance, reconciliation,
  continuation side, durable attempt, grace, risk, stop, spread, and exit are
  deterministic and locked before Q02.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC plus
  native MT5 calendar and execution state supply every runtime input. The
  standard-Wednesday proxy remains falsifiable.
- R4 `PASS`: timestamps, OHLC, logarithms, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,536 EA-registry rows and 625
root cards. It found no exact identity and no fuzzy match above its threshold.
Manual family review fixes the material boundaries:

- `QM5_41041_wti-wed-flow-fade` requires the same Wednesday components to
  oppose but requires strict **session** dominance, then fades the completed
  total. This package admits the disjoint strict **overnight**-dominant state
  and follows its reconciled total. Equality belongs to neither system.
- `QM5_41042_wti-wed-flow-agree` requires the components to share one strict
  sign. This package requires strict opposition, so their eligible states do
  not overlap.
- `QM5_41033_wti-flow-dom` aggregates all close-to-open and open-to-close
  intervals in an exact completed Monday-Friday week, enters next Monday, and
  holds to Friday. This package reads one event-clock Wednesday and owns only
  the next D1 interval.
- `QM5_41036_wti-mflow-dom` aggregates and holds over complete broker months,
  not one Wednesday session.
- `QM5_12784_progo-xti` trades crossings of two smoothed fourteen-day flow
  lines and permits signal-reversal/time exits. This package uses unsmoothed
  exact-session components, a disjoint dominance gate, and a fixed next-D1
  lifecycle.
- `QM5_41045` and `QM5_41046` compare a whole Wednesday return with a separate
  252-session trend. They do not inspect the internal Wednesday close/open
  decomposition.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback, not a symmetric WTI event-flow continuation rule.

Manual verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_OPPOSED_FLOW_STRICT_OVERNIGHT_DOMINANCE_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.
The carrier, exact event session, strict opposition, overnight-dominant state,
reconciled continuation side, Thursday attempt, and next-D1 exit are jointly
load-bearing.

## Safety And Extraction Boundary

The OWNER mission and
`decisions/2026-08-17_wti_wednesday_overnight_dominance_source_approval.md`
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
component agreement, absent strict overnight dominance, wrong continuation
side, failed reconciliation, current-bar leakage, late or repeated entry,
wrong lifecycle, nondeterminism, invalid risk mode, or an economically
unusable standard-Wednesday proxy.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-17 | bounded composite source extraction | G0 | APPROVED_SOURCE |
