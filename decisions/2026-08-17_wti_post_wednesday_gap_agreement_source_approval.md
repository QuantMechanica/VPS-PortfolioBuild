# WTI Post-Wednesday Gap-Agreement Continuation — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester ceiling
permits. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-postwed-gap-agree`
- proposed strategy ID:
  `EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026_S01`
- source ID: `EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Thursday tick after exact completed
  Monday, Tuesday, and standard-Wednesday sessions
- price state: completed Wednesday open-to-close event-session log flow plus
  the Wednesday-close-to-current-Thursday-open post-event gap
- lifecycle: require both nonzero components to share one strict sign, follow
  that confirmed direction, and close at the first later D1 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded composite packet at
`strategy-seeds/sources/EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026/source.md` and all
of its governed parents were read completely before this decision:

1. The official U.S. Energy Information Administration WPSR packet at
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md` supplies the
   ordinary Wednesday petroleum-information clock and holiday-shift caveat.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through the
   complete local source record at `strategy-seeds/sources/SRC03/source.md`
   and bounded underlying text at
   `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`, defines separate
   prior-close-to-open and open-to-close price-flow objects and treats their
   agreement or disagreement as potentially informative.
3. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, through the
   complete-paper receipt at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supplies broad own-return
   continuation lineage and explicitly includes WTI.

No source tests the exact event-session/post-event-gap conjunction, the
one-D1 horizon, or a Darwinex continuous CFD. No performance, coefficient,
significance, density, cost, drawdown, WTI-only efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible broker Thursday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed native same-day or one uniform `+1` calendar-day
   energy D1 label convention. Require the current Thursday plus exact
   immediately completed Wednesday, Tuesday, and Monday sessions; never
   substitute a missing day.
3. Persist the broker-Thursday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry or backfill.
4. Require first observation no later than 180 minutes after the executable
   Thursday D1 open.
5. Compute `event_session_flow = ln(WednesdayClose / WednesdayOpen)` and
   `post_event_gap = ln(ThursdayOpen / WednesdayClose)`.
6. Require both components finite, nonzero, and strictly equal in sign.
   Reconcile their sum to `ln(ThursdayOpen / WednesdayOpen)` within `1e-10`.
7. Positive agreement buys WTI and negative agreement sells WTI. Opposition,
   exact zero, invalid arithmetic, broken calendar identity, or failed
   reconciliation consumes Thursday flat. Magnitude never changes size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target.
9. Close at the first later D1 boundary, ordinarily Friday open. Framework
   Friday close remains enabled at broker hour 21 as a fail-safe; a three-day
   guard repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event identity, a
  complete OWNER-supplied Tier-A Williams flow extraction, and a complete-read
  peer-reviewed continuation paper including WTI, with the untested
  conjunction and horizon mismatch explicit.
- R2 `PASS`: calendar, endpoints, strict agreement, reconciliation, direction,
  attempt, grace, risk, stop, spread, and exit are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC and
  native MT5 state supply every runtime input; event-clock and D1 label
  classification remain disclosed falsification risks.
- R4 `PASS`: deterministic timestamp and log-return arithmetic only; no ML,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  hedge, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,537 registry rows and 625 root card files. It
returned `CLEAN` with no exact or fuzzy identity. Manual family review fixes
the load-bearing boundaries:

- `QM5_41042_wti-wed-flow-agree` compares Tuesday-close-to-Wednesday-open
  with Wednesday-open-to-close, so both components end at Wednesday close.
  This candidate starts with the Wednesday event session and requires a
  separate, later Wednesday-close-to-Thursday-open confirmation before entry.
- `QM5_41049_wti-wed-overnight-dom` uses the two completed components inside
  Wednesday, requires strict opposition and overnight dominance, and never
  reads the current Thursday open as a signal endpoint.
- `QM5_41041_wti-wed-flow-fade` requires strict opposition inside Wednesday,
  strict session dominance, and a contrarian side. This candidate requires
  strict agreement across the event session and the following overnight gap
  and follows that sign.
- `QM5_41043_xng-thu-flow-agree` decomposes a completed Thursday natural-gas
  session and enters Friday. This candidate is direct WTI, anchors the EIA
  Wednesday session, includes the next opening gap, and enters Thursday.
- `QM5_12579_eia-wti-aftershock` follows only after a large completed D1 event
  bar. This candidate has no magnitude, range, body, tail, mean, or breakout
  gate; the post-event gap's strict sign confirmation is load-bearing.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback, not a symmetric WTI event-flow continuation rule.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately twelve to twenty-six completed positions
per full post-warm-up year. Q02 retires on zero trades, fewer than five
positions per year, nonpositive governed economics, wrong session identity or
endpoints, absent strict agreement, wrong continuation side, failed
reconciliation, current-price leakage beyond the frozen Thursday open, late
or repeated entry, wrong lifecycle, invalid risk mode, nondeterminism, or an
unusable standard-Wednesday proxy. No weak result may be rescued by accepting
opposition or zero, adding a magnitude threshold, reversing direction,
changing the weekday, or extending the hold.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path tester
count is below the governed ceiling. If the ceiling is binding, stop before
queue mutation and record a non-live handoff.
