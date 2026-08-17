# WTI Post-Wednesday Counter-Gap Fade - Source Approval

Date: 2026-08-18

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

- proposed slug: `wti-postwed-gap-fade`
- proposed strategy ID:
  `EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026_S01`
- proposed source ID: `EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Thursday tick after exact completed
  Monday, Tuesday, and standard-Wednesday sessions
- price state: completed Wednesday event-session flow versus the frozen
  Wednesday-close-to-Thursday-open post-event counter-gap
- lifecycle: require strict opposition and event-session dominance, trade in
  the event-session sign to fade the counter-gap, and close at the next D1
  boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026/source.md`
and its governed parents were read completely within their documented bounds
before this decision:

1. The approved U.S. Energy Information Administration WPSR packet at
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md` supplies the
   ordinary Wednesday crude-oil information clock and holiday-shift caveat.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through the
   complete local source record at `strategy-seeds/sources/SRC03/source.md`
   and bounded page-15-to-30 text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`, defines separate
   close-to-open and open-to-close price-flow objects and treats their
   divergence as potentially informative.
3. Yang, Goncu, and Pantelous (2018), *International Review of Financial
   Analysis* 60, 177-196, DOI `10.1016/j.irfa.2018.09.012`, through
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, supplies broad
   commodity-reversal lineage. Its local record is not a complete-paper
   receipt and its evidence is not WTI-specific.

The existing EIA packet records the source-policy limitation on fresh generic
URL retrieval. No new webpage text is imported and no alternate retrieval
path is used. No source tests this exact event-time/decomposition/reversal
conjunction. No performance, significance, density, cost, drawdown, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible `XTIUSD.DWX` broker Thursday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or one uniform `+1`-calendar-day energy
   D1-label convention. Require current normalized Thursday plus exact
   immediately completed Wednesday, Tuesday, and Monday sessions; never shift
   or substitute a missing session.
3. Persist the exact broker-Thursday `yyyymmdd` attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry or
   backfill it.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `event_session_flow = ln(WednesdayClose / WednesdayOpen)` and
   `post_event_gap = ln(ThursdayOpen / WednesdayClose)` from completed prices
   plus the frozen current D1 opening price only.
6. Require strict sign opposition and
   `abs(event_session_flow) > abs(post_event_gap)`. Reconcile their sum to
   `ln(ThursdayOpen / WednesdayOpen)` within `1e-10`.
7. Fade the counter-gap: positive event-session flow buys WTI; negative flow
   sells WTI. Agreement, exact zero, equal component magnitude, counter-gap
   dominance, invalid arithmetic, broken calendar identity, or failed
   reconciliation consumes Thursday flat. Magnitude never changes size.
8. Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point entry-spread ceiling, and no
   target.
9. Close on the first later D1 boundary, ordinarily Friday open. Framework
   Friday close at broker hour 21 remains a fail-safe; a three-calendar-day
   guard repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

The exact weekday sequence, frozen endpoints, strict opposition,
event-session dominance, reconciliation, counter-gap-fade direction,
Thursday attempt, fixed risk, and next-D1 lifecycle are load-bearing. No
magnitude, volatility, SMA, range, tail, breakout, inventory-value, or season
filter is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: an approved official government
  event packet, a complete OWNER-supplied Tier-A practitioner extraction, and
  a named peer-reviewed commodity-reversal publication. The incomplete Yang
  local full-paper record and untested conjunction are explicit.
- R2 `PASS`: weekdays, normalized labels, frozen endpoints, opposition,
  dominance, reconciliation, fade direction, attempt state, timing, risk,
  stop, spread, and exit are deterministic and locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC and
  native MT5 execution state supply every runtime input; the energy label
  convention and event proxy remain falsifiable.
- R4 `PASS`: timestamps, OHLC, logarithms, arithmetic, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, hedge, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,540 registry rows and 625 card files
and returned `CLEAN` with no exact or fuzzy match. A repository-wide formula
search found the completed-event-session/post-event-gap endpoint pair only in
the strict-agreement carriers `QM5_41050` and `QM5_41052`. Manual semantic
review fixes the nearest boundaries:

- `QM5_41050` uses the same WTI endpoints but requires strict agreement and
  follows the common sign. This candidate requires strict opposition plus
  event-session dominance and fades the later counter-gap, so eligible states
  are disjoint.
- `QM5_41041` compares the pre-event Tuesday-close/Wednesday-open gap with the
  Wednesday session and fades a session-dominant completed Wednesday total.
  This candidate instead compares the event session with the later frozen
  Wednesday-close/Thursday-open gap and trades against that counter-gap.
- `QM5_41049` requires opposed internal-Wednesday components and pre-event
  overnight dominance, then follows that total. This candidate requires the
  event session to dominate a later post-event gap.
- `QM5_41042` requires agreement inside Wednesday and never reads Thursday
  open.
- `QM5_12590` requires range/body/tail/SMA-stretch exhaustion and can hold
  four days; this candidate has no such filters and exits at the next D1
  boundary.
- `QM5_20133` and `QM5_20134` trade exact M30 release-window sequences before
  the completed D1/post-open state exists.
- `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 retires on zero trades, fewer than five positions
per year, nonpositive governed economics, wrong session identity or
endpoints, absent strict opposition or event-session dominance, wrong fade
side, failed reconciliation, current-price leakage beyond the frozen
Thursday open, late or repeated entry, wrong lifecycle, invalid risk mode,
nondeterminism, or an unusable standard-Wednesday proxy. No weak result may be
rescued by accepting agreement or counter-gap dominance, adding a magnitude
threshold, reversing direction, changing the weekday, or extending the hold.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path tester
count is below the governed ceiling. At the ceiling, stop before queue
mutation and record a non-live handoff.
