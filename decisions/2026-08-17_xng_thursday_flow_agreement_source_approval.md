# XNG Standard-Thursday Strict Flow-Agreement Continuation — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01 validation,
and one paced target-only Q02 enqueue if the tester ceiling permits. This
decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission expressly permits a second XNG edge
only when its logic is different from `QM5_12567`, and requires structural,
low-frequency, reputable-source, `RISK_FIXED`, non-live work without a
portfolio-gate or T_Live-manifest mutation.

## Candidate Identity

- proposed slug: `xng-thu-flow-agree`
- proposed strategy ID: `EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026_S01`
- source ID: `EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026`
- carrier: exact `XNGUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Friday tick after exact completed
  Tuesday, Wednesday, and Thursday sessions
- price state: completed Thursday close-to-open and open-to-close flows
- lifecycle: require strict component sign agreement, follow the completed
  Thursday total, and close at the next D1 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026/source.md` was
read completely before this decision. Its governed parents were also read
within their documented bounds:

1. The approved U.S. Energy Information Administration WNGSR packet at
   `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md` supplies
   the ordinary Thursday 10:30 a.m. eastern-time natural-gas information clock
   and holiday-shift caveat.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   `raw/probe_pp15-30.txt`, defines close-to-open and open-to-close price flows
   and their separate accumulation.
3. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, through the governed
   complete-paper receipt at `strategy-seeds/sources/MOP-TSMOM-2012/source.md`,
   supplies broad own-return continuation lineage and explicitly includes
   natural gas in its commodity universe.

No source tests the exact event-time/decomposition/continuation conjunction.
The JFE study uses materially longer horizons. No performance, significance,
density, cost, drawdown, CFD equivalence, decorrelation, or portfolio result
transfers.

## Locked Mechanic

On the first executable tick of each eligible broker Friday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or one uniform `+1` energy D1 label
   convention. Require current Friday plus exact immediately completed
   Thursday, Wednesday, and Tuesday sessions; never substitute a missing day.
3. Persist the broker-Friday attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill it.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `overnight_flow = ln(ThursdayOpen / WednesdayClose)` and
   `session_flow = ln(ThursdayClose / ThursdayOpen)` from completed prices.
6. Require both components nonzero and strictly same-sign. Reconcile their sum
   to `ln(ThursdayClose / WednesdayClose)` within `1e-10`.
7. Follow the completed Thursday total: positive buys XNG and negative sells
   XNG. Opposition, exact zero, invalid arithmetic, broken calendar identity,
   or failed reconciliation consumes Friday flat. Magnitude never scales size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target.
9. Close at the first later D1 boundary, ordinarily Monday open. Framework
   Friday close is disabled because the locked one-D1 lifecycle crosses the
   weekend; a four-day guard repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete Tier-A Williams decomposition, and complete-paper peer-reviewed JFE
  continuation lineage with explicit XNG carrier relevance. The untested
  conjunction, longer academic horizon, and weekend translation are explicit.
- R2 `PASS`: calendar, endpoints, agreement, reconciliation, continuation
  direction, attempt state, timing, risk, stop, spread, and exit are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC and native
  MT5 state supply every runtime input; carrier label normalization remains a
  disclosed falsification risk.
- R4 `PASS`: deterministic calendar and return arithmetic only; no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,530 registry rows and 625 flat card files. It
found no exact identity and surfaced only the expected weekly/monthly WTI flow-
agreement family for manual review.

- `QM5_41029` forms over a full WTI week, enters Monday, and holds to Friday.
- `QM5_41034` forms and holds over complete WTI broker months.
- `QM5_41042` uses the analogous strict-agreement object on the WTI Wednesday
  petroleum clock, not the XNG Thursday storage clock or its weekend lifecycle.
- `QM5_20163` enters a Thursday XNG short from a negative 252-D1 trend state;
  this candidate waits for completed Thursday flow, enters Friday, and is
  symmetric.
- `QM5_12819` is an unconditional Thursday XNG short; this candidate is
  conditional and follows either strict-agreement sign on Friday.
- `QM5_20011` is unconditional long Friday-to-Wednesday calendar carry; this
  candidate exits at the first later D1 boundary and can be long or short.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` use exact-clock M30 release impulse,
  reclaim, or breakout mechanics and do not use a completed-D1 flow split.
- `QM5_12567` is a long-only cumulative-RSI2 pullback above a slow mean.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
component opposition, wrong continuation direction, failed reconciliation,
late or repeated entry, wrong next-D1 lifecycle, nondeterminism, invalid risk
mode, or an unusable standard-Thursday proxy. Source-to-rule distance,
futures/CFD basis, holiday shifts, financing, XNG gaps, weekend exposure, and
later book correlation are first-order risks. Q09 alone may establish realized
correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path capacity
check is below the governed tester ceiling. At the ceiling, stop before queue
mutation and report the handoff.
