# XNG Standard-Thursday Session-Dominant Flow Fade — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01 validation,
and one paced target-only Q02 enqueue if the tester ceiling permits. This
decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission expressly permits a second XNG edge
only when its logic differs from `QM5_12567`, and requires structural,
low-frequency, reputable-source, `RISK_FIXED`, non-live work without a
portfolio-gate or T_Live-manifest mutation.

## Candidate Identity

- proposed slug: `xng-thu-flow-fade`
- proposed strategy ID: `EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026_S01`
- source ID: `EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026`
- carrier: exact `XNGUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Friday tick after exact completed
  Tuesday, Wednesday, and Thursday sessions
- price state: completed Thursday close-to-open and open-to-close flows
- lifecycle: require strict component opposition and strict session dominance,
  fade the completed Thursday total, and close at the next D1 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026/source.md` was
read completely before this decision. Its governed parents were also read
within their documented bounds:

1. The approved U.S. Energy Information Administration WNGSR packet at
   `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md` supplies
   the ordinary Thursday 10:30 a.m. eastern-time natural-gas information clock
   and holiday-shift caveat.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   `raw/probe_pp15-30.txt`, defines close-to-open and open-to-close price flows,
   labels the latter as professional-session flow, and treats their separate
   behavior as potentially informative.
3. Yang, Goncu, and Pantelous (2018), *International Review of Financial
   Analysis* 60, 177-196, DOI `10.1016/j.irfa.2018.09.012`, through the
   governed partial extraction at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, supplies broad
   fixed-horizon commodity-futures reversal lineage. The local record is not a
   complete-paper receipt and does not establish an XNG-specific result.

No source tests the exact event-time/decomposition/reversal conjunction. No
performance, significance, density, cost, drawdown, CFD equivalence,
decorrelation, or portfolio result transfers.

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
6. Require both components nonzero and strictly opposite in sign. Require
   `abs(session_flow) > abs(overnight_flow)` and reconcile their sum to
   `ln(ThursdayClose / WednesdayClose)` within `1e-10`.
7. Fade the completed Thursday total: positive sells XNG and negative buys
   XNG. Agreement, equality, exact zero, invalid arithmetic, broken calendar
   identity, or failed reconciliation consumes Friday flat. Magnitude never
   scales size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target.
9. Close at the first later D1 boundary, ordinarily Monday open. Framework
   Friday close is disabled because the locked one-D1 lifecycle crosses the
   weekend; a four-day guard repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete Tier-A Williams decomposition, and peer-reviewed commodity reversal
  lineage with the partial local academic record and lack of an XNG-specific
  test explicit.
- R2 `PASS`: calendar, endpoints, opposition, dominance, reconciliation,
  contrarian direction, attempt state, timing, risk, stop, spread, and exit are
  locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC and native
  MT5 state supply every runtime input; carrier label normalization remains a
  disclosed falsification risk.
- R4 `PASS`: deterministic calendar and return arithmetic only; no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,531 registry rows and 625 root card files. It
returned `CLEAN` with no exact or fuzzy identity. Manual family review fixes
the load-bearing boundaries:

- `QM5_41043_xng-thu-flow-agree` requires strict component agreement and
  follows the completed Thursday direction. This candidate requires strict
  opposition plus session dominance and fades the completed direction.
- `QM5_41041_wti-wed-flow-fade` uses WTI's Wednesday petroleum clock, enters
  Thursday, and normally exits Friday. This candidate uses XNG's Thursday
  storage clock, enters Friday, and owns the next D1 interval across a weekend.
- `QM5_12819_xng-thu-fade` is an unconditional Thursday short. This candidate
  waits until Friday, is symmetric, and trades only a completed opposed-flow
  state.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` use M30 release impulse,
  reclaim, or live-breakout objects inside the Thursday event session. This
  candidate uses completed D1 endpoints and never enters during the release
  session.
- `QM5_41037` and `QM5_41038` form over a complete broker month and hold to the
  next month; this candidate isolates one Thursday and exits next D1.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback
  above a slow mean, with no event clock or price-flow decomposition.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
component agreement, absent strict session dominance, wrong contrarian side,
failed reconciliation, late or repeated entry, wrong next-D1 lifecycle,
nondeterminism, invalid risk mode, or an unusable standard-Thursday proxy.
Source-to-rule distance, futures/CFD basis, holiday shifts, financing, XNG
gaps, weekend exposure, and later book correlation are first-order risks. Q09
alone may establish realized correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path capacity
check is below the governed tester ceiling. At the ceiling, stop before queue
mutation and report the handoff.
