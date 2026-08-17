# XNG Post-Thursday Counter-Gap Fade - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester ceiling
permits. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission explicitly permits a second XNG
edge only when its logic differs from `QM5_12567`; it requires structural,
low-frequency logic, reputable-source criteria, `RISK_FIXED` backtests, and no
live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xng-postthu-gap-fade`
- proposed strategy ID:
  `EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026_S01`
- proposed source ID: `EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026`
- carrier: exact `XNGUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Friday tick after exact completed
  Tuesday, Wednesday, and standard-Thursday sessions
- price state: completed Thursday event-session flow versus the frozen
  Thursday-close-to-Friday-open post-event counter-gap
- lifecycle: require strict opposition and event-session dominance, trade in
  the event-session sign to fade the counter-gap, and normally flatten through
  framework Friday close

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026/source.md`
and its governed parents were read completely within their documented bounds
before this decision:

1. The approved EIA packet at
   `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md` supplies
   the ordinary Thursday natural-gas information clock and holiday-shift
   caveat.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded page-15-
   to-30 text at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt`, defines
   separate close-to-open and open-to-close price-flow objects.
3. Yang, Goncu, and Pantelous (2018), *International Review of Financial
   Analysis* 60, 177-196, DOI `10.1016/j.irfa.2018.09.012`, through
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, supplies broad
   commodity-reversal lineage. Its local record is not a complete-paper
   receipt and its evidence is not XNG-specific.
4. The governed XNG agreement packet fixes the exact completed-Thursday and
   frozen-Friday-open endpoints without transferring its direction or result.
5. The governed WTI counter-gap packet fixes the abstract opposition and
   dominance construction on a different carrier and event clock without
   transferring any WTI claim.

The deterministic source router returned `DEFERRED:SOURCE_POLICY` for a fresh
EIA generic-page read on 2026-08-18. No workaround was attempted, no new web
text is imported, and the limitation is preserved in the source packet.

No source tests this exact event-time/decomposition/reversal conjunction. No
performance, significance, density, cost, drawdown, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible `XNGUSD.DWX` broker Friday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or one uniform `+1`-calendar-day energy
   D1-label convention. Require current normalized Friday plus exact
   immediately completed Thursday, Wednesday, and Tuesday sessions; never
   shift or substitute a missing session.
3. Persist the exact broker-Friday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry or backfill.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `event_session_flow = ln(ThursdayClose / ThursdayOpen)` and
   `post_event_gap = ln(FridayOpen / ThursdayClose)` from completed prices plus
   the frozen current D1 opening price only.
6. Require strict sign opposition and
   `abs(event_session_flow) > abs(post_event_gap)`. Reconcile their sum to
   `ln(FridayOpen / ThursdayOpen)` within `1e-10`.
7. Fade the counter-gap: positive event-session flow buys XNG; negative flow
   sells XNG. Agreement, exact zero, equal component magnitude, counter-gap
   dominance, invalid arithmetic, broken calendar identity, or failed
   reconciliation consumes Friday flat. Magnitude never changes size.
8. Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
   `3.5 * ATR(20,D1)` hard stop, a 3,000-point entry-spread ceiling, and no
   target.
9. Flatten through framework Friday close at broker hour 21. The first later
   D1 boundary and a four-calendar-day stale guard repair only a survivor.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

The exact weekday sequence, frozen endpoints, strict opposition,
event-session dominance, reconciliation, counter-gap-fade direction, Friday
attempt, fixed risk, and same-Friday lifecycle are load-bearing. No magnitude,
volatility, moving-mean, range, tail, breakout, inventory-value, weather, or
season filter is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official government
  event lineage, a complete OWNER-supplied Tier-A practitioner extraction, and
  a named peer-reviewed commodity-reversal publication. The incomplete Yang
  local full-paper record and untested conjunction are explicit.
- R2 `PASS`: weekdays, normalized labels, frozen endpoints, opposition,
  dominance, reconciliation, fade direction, attempt state, timing, risk,
  stop, spread, and exit are deterministic and locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC and
  native MT5 execution state supply every runtime input; the energy label
  convention and event proxy remain falsifiable.
- R4 `PASS`: timestamps, OHLC, logarithms, arithmetic, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  hedge, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,541 registry rows and 625 card files
and returned `CLEAN` with no exact or fuzzy match. Repository formula review
found the completed-event-session/post-event-gap endpoint pair only in
`QM5_41050`, `QM5_41052`, and `QM5_41053`. Manual semantic review fixes the
nearest boundaries:

- `QM5_41052` uses the same XNG endpoints but requires strict agreement and
  follows the common sign. This candidate requires strict opposition plus
  event-session dominance and fades the later counter-gap, so eligible states
  are disjoint.
- `QM5_41044` compares the earlier Wednesday-close/Thursday-open flow with
  Thursday's event session, fades the completed Thursday total, and normally
  holds across the weekend. This candidate uses the later Thursday-close/
  frozen-Friday-open counter-gap and is normally flat Friday night.
- `QM5_41043` and `QM5_41048` never read the frozen Friday open.
- `QM5_12898` requires range, body, tail, slow-mean, and multiday conditions.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` are exact-clock M30 event
  sequences before this completed cross-boundary state exists.
- `QM5_41053` uses WTI, the Wednesday petroleum clock, a Thursday decision,
  and oil-specific execution geometry.
- `QM5_12567` is a long-only two-day oscillator pullback, not a scheduled-
  event symmetric counter-gap fade.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 retires on zero trades, fewer than five positions
per year, nonpositive governed economics, wrong session identity or endpoints,
absent strict opposition or event-session dominance, wrong fade side, failed
reconciliation, current-price leakage beyond the frozen Friday open, late or
repeated entry, wrong lifecycle, invalid risk mode, nondeterminism, or an
unusable standard-Thursday proxy. No weak result may be rescued by accepting
agreement or counter-gap dominance, adding a magnitude threshold, reversing
direction, changing the weekday, or extending the hold.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path tester
count is below the governed ceiling. At the ceiling, stop before queue
mutation and record a non-live handoff.
