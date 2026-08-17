# XNG Post-Thursday Gap-Agreement Friday Continuation — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01 validation,
and one paced target-only Q02 enqueue if both tester and host-CPU ceilings
permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission expressly permits a second XNG edge
only when its logic differs from `QM5_12567`, and requires structural,
low-frequency, reputable-source, `RISK_FIXED`, non-live work without a
portfolio-gate or `T_Live`-manifest mutation.

## Candidate Identity

- proposed slug: `xng-postthu-gap-agree`
- proposed strategy ID: `EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026_S01`
- source ID: `EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026`
- carrier: exact `XNGUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Friday tick after exact completed
  Tuesday, Wednesday, and Thursday sessions
- price state: completed Thursday event-session return plus frozen Thursday-
  close-to-Friday-open gap
- lifecycle: require strict cross-boundary sign agreement, follow the common
  sign only through the Friday session, and flatten at broker hour 21

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026/source.md` and
both governed composite parents were read completely before this decision:

1. `EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026` supplies the official EIA
   standard-Thursday natural-gas information clock, Williams price-flow
   decomposition lineage, and peer-reviewed continuation lineage from
   Moskowitz, Ooi, and Pedersen that explicitly includes natural gas.
2. `EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026` supplies only the predeclared
   event-session/next-opening-gap confirmation object. Its WTI carrier,
   Wednesday clock, and any later evidence do not transfer.

The primary citation chain is the U.S. Energy Information Administration,
*Weekly Natural Gas Storage Report* and release schedule; Williams (1999),
*Long-Term Secrets to Short-Term Trading*, Wiley Trading; and Moskowitz, Ooi,
and Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

No source tests the exact cross-boundary conjunction, same-Friday continuation,
Darwinex continuous CFD, label normalization, fixed risk, spread cap, or stop.
No performance, significance, density, cost, drawdown, CFD-equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible broker Friday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed native same-day or one uniform `+1` calendar-day
   energy D1 label convention. Require current Friday plus exact completed
   Thursday, Wednesday, and Tuesday; never substitute a missing session.
3. Persist the broker-Friday attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill it.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `event_session_flow = ln(ThursdayClose / ThursdayOpen)` and
   `post_event_gap = ln(FridayOpen / ThursdayClose)` from completed or frozen
   boundary prices only.
6. Require both components nonzero and strictly same-sign. Reconcile their sum
   to `ln(FridayOpen / ThursdayOpen)` within `1e-10`.
7. Follow the common sign: positive buys XNG and negative sells XNG. Opposition,
   exact zero, invalid arithmetic, broken calendar identity, or failed
   reconciliation consumes Friday flat. Magnitude never scales size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target.
9. Close through framework Friday close at broker hour 21. First-later-D1 and
   four-calendar-day exits repair only a survivor.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete Tier-A Williams decomposition lineage, and complete-read peer-
  reviewed JFE continuation evidence including natural gas. The untested
  conjunction and much shorter horizon are explicit.
- R2 `PASS`: calendar, endpoints, frozen open, agreement, reconciliation,
  continuation direction, attempt state, timing, risk, stop, spread, and exit
  are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC and native
  MT5 state supply every runtime input; carrier label normalization and the
  standard-Thursday proxy remain disclosed falsification risks.
- R4 `PASS`: deterministic calendar and return arithmetic only; no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,539 registry rows and 625 flat card files. It
returned `CLEAN` with no exact or fuzzy identity. Manual family review fixes
the material differences:

- `QM5_41043` splits completed Thursday into Wednesday-close/Thursday-open and
  Thursday-session flows, then holds Friday across the weekend. This candidate
  starts at Thursday open, requires the later Friday opening gap, and is flat
  Friday night.
- `QM5_41044` requires internal-Thursday opposition and session-dominant fade;
  this candidate requires cross-boundary agreement and continuation.
- `QM5_41047` and `QM5_41048` combine Thursday event return with a 252-session
  trend and hold to the next D1 boundary; this candidate has no slow trend and
  uses a frozen opening-gap confirmation.
- `QM5_12898` requires event magnitude, body, close location, moving-average
  state, and a multiday hold; none exists here.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` trade M30 release-window impulse,
  reclaim, or breakout objects rather than a completed event day plus next
  opening boundary.
- `QM5_20160` is a Friday short selected by a negative 252-D1 trend and
  explicitly omits the Thursday-close/Friday-open gap.
- `QM5_12567` is a long-only cumulative-RSI2 pullback above a slow mean.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_FRIDAY_SESSION_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately twelve to twenty-eight completed positions
per full post-warm-up year. Q02 retires on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday identity or endpoints,
component opposition, wrong continuation direction, failed reconciliation,
current-Friday leakage beyond the frozen open, late or repeated entry, wrong
Friday lifecycle, nondeterminism, invalid risk mode, or an unusable standard-
Thursday proxy. Q09 alone may establish realized portfolio correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. One target-only Q02 item may be
enqueued only below both governed capacity ceilings. At either ceiling, stop
before queue mutation and report the handoff.
