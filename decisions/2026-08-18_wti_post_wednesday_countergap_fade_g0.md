# G0 Decision - QM5_41053 WTI Post-Wednesday Counter-Gap Fade

Date: 2026-08-18

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-18_wti_post_wednesday_countergap_fade_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41053_wti-postwed-gap-fade_card.md`.

## Identity

- EA ID: `QM5_41053`, allocated by the deterministic registry at commit
  `2cd8ff7a9`
- slug: `wti-postwed-gap-fade`
- strategy ID: `EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026_S01`
- source approval commit: `afdedce04`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, registered magic `410530000`
- mechanic: at the first genuine broker Thursday, require the completed
  Wednesday event-session flow to oppose the frozen Wednesday-close-to-
  Thursday-open gap while remaining strictly dominant; trade in the event-
  session sign to fade the counter-gap and close at the next D1 boundary

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, complete OWNER-supplied Williams price-flow extraction, and named
  peer-reviewed commodity-reversal lineage. No source tests this conjunction;
  the local Yang record is not a complete-paper receipt and its universe and
  horizons differ.
- R2 `PASS`: exact weekdays, energy-label normalization, frozen Thursday open,
  strict opposition, event-session dominance, reconciliation, fade side,
  attempt persistence, grace, fixed risk, hard stop, spread cap, and next-D1
  exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XTIUSD.DWX` D1 OHLC,
  quotes, broker calendar, positions, deal history, and terminal state supply
  every runtime input. The price-only standard-Wednesday classification
  remains falsifiable.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, hedge, or pyramid.

## Duplicate Review

The canonical pre-allocation checker scanned 4,540 registry rows and 625 card
files and returned `CLEAN`. Repository formula search found the completed
event-session/post-event-gap endpoint pair only in the strict-agreement WTI
and XNG carriers. Manual review confirms:

- `QM5_41050` admits only cross-boundary agreement and follows the sign; this
  candidate admits only opposition plus event-session dominance and fades the
  later gap, so their eligible states are disjoint;
- `QM5_41041`, `QM5_41042`, and `QM5_41049` decompose internal Wednesday flow
  using the earlier Tuesday-close/Wednesday-open endpoint and never use the
  later frozen Thursday-open counter-gap in this identity;
- `QM5_12590` requires magnitude, range, tail, and slow-mean exhaustion with a
  multiday hold;
- `QM5_20133` and `QM5_20134` are exact-clock M30 event sequences; and
- `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and registered magic `410530000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Thursday plus exact completed Wednesday, Tuesday, and Monday
  at calendar offsets one, two, and three, with no substitution;
- first-Thursday decision within 180 minutes and one durable `yyyymmdd`
  attempt persisted before every fallible gate;
- `ln(WednesdayClose / WednesdayOpen)` and
  `ln(ThursdayOpen / WednesdayClose)` using the frozen D1 open only;
- strict nonzero component opposition, strict event-session dominance, and
  `1e-10` reconciliation to `ln(ThursdayOpen / WednesdayOpen)`;
- positive event-session flow maps to BUY and negative maps to SELL;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both news axes OFF, next-D1 exit, three-day stale repair, and framework
  Friday close ON at broker hour 21; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No inventory number, event-calendar file, magnitude threshold, dominance
ratio, volatility signal, moving mean, oscillator, range, tail, breakout,
season selector, external runtime input, retry, scale-in, grid, martingale,
hedge, pyramid, optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count is below the governed ceiling. It does not authorize a
manual tester dispatch or tester control.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong weekday/endpoints, absent strict
opposition or event-session dominance, wrong fade side, failed
reconciliation, current-price leakage beyond frozen Thursday open,
late/repeated entry, wrong lifecycle, invalid risk mode, nondeterminism, or an
unusable standard-Wednesday proxy. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
