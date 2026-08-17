# G0 Decision - QM5_41050 WTI Post-Wednesday Gap-Agreement Continuation

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_wti_post_wednesday_gap_agreement_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41050_wti-postwed-gap-agree_card.md`.

## Identity

- EA ID: `QM5_41050`, allocated in commit `ecf6d8322`
- slug: `wti-postwed-gap-agree`
- strategy ID: `EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026_S01`
- source approval commit: `8ee045854`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, registered magic `410500000`
- mechanic: at the first genuine broker Thursday, require the completed
  Wednesday event-session flow to agree strictly with the frozen Wednesday-
  close-to-Thursday-open gap; follow the reconciled common sign and close at
  the next D1 boundary

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, complete OWNER-supplied Williams price-flow extraction, and a
  complete-paper peer-reviewed own-return continuation study explicitly
  including WTI. No source tests this conjunction, and the paper horizons are
  materially longer than one D1 interval.
- R2 `PASS`: exact weekdays, energy-label normalization, frozen Thursday open,
  strict agreement, reconciliation, continuation side, attempt persistence,
  entry grace, fixed risk, hard stop, spread cap, and next-D1 exit are
  mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XTIUSD.DWX` D1 OHLC,
  quotes, broker calendar, positions, deal history, and terminal state supply
  every runtime input. The price-only standard-Wednesday classification
  remains falsifiable.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, hedge, or pyramid.

## Duplicate Review

The canonical pre-allocation checker scanned 4,537 registry rows and 625 card
files and returned `CLEAN` with no exact or fuzzy identity. Manual review
confirms:

- `QM5_41042` compares the prior overnight gap with the Wednesday session;
  this candidate compares that session with the later post-event gap;
- `QM5_41049` requires opposed internal-Wednesday components and overnight
  dominance; this candidate requires cross-boundary agreement;
- `QM5_41041` fades opposed, session-dominant internal-Wednesday flow;
- `QM5_41043` uses XNG's completed Thursday and enters Friday;
- `QM5_12579` requires a large event bar, whereas this candidate has no
  magnitude, body, range, or tail threshold;
- `QM5_12988` uses two events plus moving-average/channel confirmation; and
- `QM5_12567` is a long-only XNG oscillator pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and registered magic `410500000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Thursday plus exact completed Wednesday, Tuesday, and Monday
  at calendar offsets one, two, and three, with no substitution;
- first-Thursday decision within 180 minutes and one durable `yyyymmdd`
  attempt persisted before every fallible gate;
- `ln(WednesdayClose / WednesdayOpen)` and
  `ln(ThursdayOpen / WednesdayClose)` using the frozen D1 open only;
- strict nonzero component agreement and `1e-10` reconciliation to
  `ln(ThursdayOpen / WednesdayOpen)`;
- positive common sign maps to BUY and negative maps to SELL;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point
  spread ceiling;
- both news axes OFF, next-D1 exit, three-day stale repair, and framework
  Friday close ON at broker hour 21; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No inventory number, event calendar file, magnitude threshold, gap ratio,
volatility signal, moving mean, oscillator, range, tail, breakout, season
selector, external runtime input, retry, scale-in, grid, martingale, hedge,
pyramid, optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count is below the governed ceiling. It does not authorize a
manual tester dispatch or tester control.

Expected cadence is approximately twelve to twenty-six completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than
five/year, nonpositive governed economics, wrong weekday/endpoints, absent
strict agreement, wrong continuation side, failed reconciliation, current-
price leakage beyond frozen Thursday open, late/repeated entry, wrong
lifecycle, invalid risk mode, nondeterminism, or an unusable standard-
Wednesday proxy. Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
