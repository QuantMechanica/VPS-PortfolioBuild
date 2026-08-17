# WTI Standard-Wednesday Session-Dominant Flow Fade - Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester ceiling
permits. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity or energy sleeve outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-wed-flow-fade`
- proposed strategy ID: `EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026_S01`
- proposed source ID: `EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable tick of broker Thursday after exact
  completed Monday, Tuesday, and Wednesday sessions
- price state: completed Wednesday close-to-open flow versus completed
  Wednesday open-to-close flow
- lifecycle: require strict component opposition and strict session
  dominance, fade the completed Wednesday total, and close at the next D1
  boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026/source.md` was
read completely before this decision. Its governed parents were also read in
full within their documented bounds:

1. The approved U.S. Energy Information Administration WPSR packet at
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md` supplies the
   ordinary Wednesday crude-oil information clock and explicit holiday-shift
   caveat. It does not define a trade.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through the
   OWNER-supplied Tier-A extraction at
   `strategy-seeds/sources/SRC03/source.md` and complete bounded page-15-to-30
   text, defines prior-close-to-open and open-to-close flows and discusses
   their separate accumulation and disagreement. It does not test this WTI
   rule.
3. Yang, Goncu, and Pantelous (2018), *International Review of Financial
   Analysis* 60, 177-196, DOI `10.1016/j.irfa.2018.09.012`, through the
   governed record at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, supplies broad
   commodity-reversal lineage. The repository record is not a complete-paper
   receipt and its Chinese-futures evidence is not WTI-specific.

The existing EIA packet records the source-policy limitation on fresh generic
URL retrieval. No new webpage text is imported and no alternate retrieval path
is used. No source tests this exact event-time/decomposition/reversal
conjunction. No performance, significance, density, cost, drawdown, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible `XTIUSD.DWX` broker Thursday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or one uniform `+1`-calendar-day energy
   D1 label convention. Require the current normalized date to equal broker
   Thursday and completed shifts 1, 2, and 3 to be exact Wednesday, Tuesday,
   and Monday sessions. Never shift or substitute a missing session.
3. Persist the exact broker-Thursday attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill it.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `overnight_flow = ln(WednesdayOpen / TuesdayClose)` and
   `session_flow = ln(WednesdayClose / WednesdayOpen)` from completed prices.
6. Require strict sign opposition and
   `abs(session_flow) > abs(overnight_flow)`. Reconcile their sum to
   `ln(WednesdayClose / TuesdayClose)` within `1e-10`.
7. Fade the completed Wednesday total: positive total sells WTI; negative
   total buys WTI. Agreement, exact zero, equal component magnitude, invalid
   arithmetic, broken calendar identity, or failed reconciliation consumes
   Thursday flat. Signal magnitude never scales size.
8. Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point entry-spread ceiling, and no
   target.
9. Close on the first later D1 boundary, ordinarily Friday open. Framework
   Friday close at broker hour 21 remains a fail-safe; a three-calendar-day
   guard repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

The exact weekday sequence, completed close/open endpoints, strict opposition,
strict session dominance, reconciliation, contrarian direction, Thursday
attempt, fixed risk, and next-D1 lifecycle are load-bearing. No magnitude,
volatility, SMA, range, tail, breakout, inventory-value, or season filter is
authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one approved official government
  event packet, one complete OWNER-supplied Tier-A practitioner extraction,
  and one named peer-reviewed commodity-reversal publication. The incomplete
  local full-paper record and untested conjunction are explicit.
- R2 `PASS`: weekdays, normalized labels, completed endpoints, opposition,
  dominance, reconciliation, fade direction, attempt state, timing, risk,
  stop, spread, and exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native MT5 execution state
  supply every runtime input; the energy label offset is governed.
- R4 `PASS`: timestamps, OHLC, logarithms, arithmetic, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,528 registry rows and 625 card files
and returned `CLEAN` with no exact or fuzzy match. Manual semantic review fixes
the nearest boundaries:

- `QM5_12590_eia-wti-wpsr-fade` requires range/body/tail/SMA-stretch
  exhaustion and can hold four days. This candidate requires internal
  overnight/session opposition plus session dominance, uses no magnitude or
  mean state, and exits at the next D1 boundary.
- `QM5_12579` follows a large D1 event bar; `QM5_12988` requires two aligned
  event reactions plus moving-average and channel confirmation.
- `QM5_20133` and `QM5_20134` use exact M30 release/pullback or release/reclaim
  sequences and close within the same session. This candidate acts only after
  a completed D1 Wednesday and owns the following D1 interval.
- `QM5_41029`, `QM5_41032`, and `QM5_41033` form from an entire completed week,
  enter Monday, and close Friday. This candidate forms from one Wednesday,
  enters Thursday, trades only a session-dominant disagreement, and closes at
  the next D1 boundary.
- `QM5_41040` is a synchronized two-metal weekly relative basket. This
  candidate is direct WTI with no relative subtraction or paired execution.
- `QM5_12567` is a long-only two-day oscillator pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong weekday identity or endpoints,
current-bar leakage, component agreement, absent session dominance, wrong fade
direction, failed reconciliation, late or repeated entry, wrong lifecycle,
nondeterminism, invalid risk mode, or an unusable standard-Wednesday proxy.
Source-to-rule distance, futures/CFD basis, holiday shifts, financing, gaps,
and later book correlation are first-order risks. Q09 alone may establish
realized correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path capacity
check is below the governed tester ceiling. At the ceiling, stop before queue
mutation and report the handoff.
