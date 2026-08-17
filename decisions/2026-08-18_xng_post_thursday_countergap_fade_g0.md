# G0 Decision - QM5_41054 XNG Post-Thursday Counter-Gap Fade

Date: 2026-08-18

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-18_xng_post_thursday_countergap_fade_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41054_xng-postthu-gap-fade_card.md`.

## Identity

- EA ID: `QM5_41054`, allocated by the deterministic registry at commit
  `bd394ac36`
- slug: `xng-postthu-gap-fade`
- strategy ID: `EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026_S01`
- source approval commit: `860798f0a`
- magic allocation commit: `061ebd1a4`
- carrier: exact `XNGUSD.DWX`, D1, slot 0, registered magic `410540000`
- mechanic: at the first genuine broker Friday, require completed Thursday
  event-session flow to oppose the frozen Thursday-close-to-Friday-open gap
  while remaining strictly dominant; trade in the event-session sign to fade
  the smaller counter-gap and use the broker-hour-21 Friday close

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, complete OWNER-supplied Williams price-flow extraction, and named
  peer-reviewed commodity-reversal lineage. No source tests this conjunction;
  the local Yang record is not a complete-paper receipt and its universe and
  horizons differ.
- R2 `PASS`: exact weekdays, energy-label normalization, frozen Friday open,
  strict opposition, event-session dominance, reconciliation, fade side,
  attempt persistence, grace, fixed risk, hard stop, spread cap, and same-
  Friday exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XNGUSD.DWX` D1 OHLC,
  quotes, broker calendar, positions, deal history, and terminal state supply
  every runtime input. The price-only standard-Thursday classification remains
  falsifiable.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, hedge, or pyramid.

## Duplicate Review

The canonical pre-allocation checker scanned 4,541 registry rows and 625 card
files and returned `CLEAN`. Manual review confirms:

- `QM5_41052` admits only cross-boundary agreement and follows the common
  sign; this candidate admits only opposition plus event-session dominance
  and follows the earlier event-session sign, so their eligible states are
  disjoint;
- `QM5_41044` uses the earlier Wednesday-close/Thursday-open component and
  holds across the weekend, rather than reading the later frozen Friday-open
  counter-gap;
- the M30 storage-event candidates act before this completed D1/next-open
  state exists;
- `QM5_41053` applies the abstract construction to WTI's different Wednesday
  information clock and carrier; and
- `QM5_12567` is a long-only two-day cumulative-RSI XNG pullback.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XNGUSD.DWX` D1 slot 0 and registered magic `410540000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Friday plus exact completed Thursday, Wednesday, and Tuesday
  at calendar offsets one, two, and three, with no substitution;
- first-Friday decision within 180 minutes and one durable `yyyymmdd` attempt
  persisted before every fallible gate;
- `ln(ThursdayClose / ThursdayOpen)` and
  `ln(FridayOpen / ThursdayClose)` using the frozen D1 open only;
- strict nonzero component opposition, strict event-session dominance, and
  `1e-10` reconciliation to `ln(FridayOpen / ThursdayOpen)`;
- positive event-session flow maps to BUY and negative maps to SELL;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 3,000-point spread
  ceiling;
- both news axes OFF, framework Friday close ON at broker hour 21, first-later-
  D1 survivor repair, and a four-day stale guard; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No storage value, event-calendar file, magnitude threshold, dominance ratio,
volatility signal, moving mean, oscillator, range, tail, breakout, season
selector, external runtime input, retry, scale-in, grid, martingale, hedge,
pyramid, optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count and host CPU are below the governed ceilings. It does not
authorize a manual tester dispatch or tester control.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong weekday/endpoints, absent strict
opposition or event-session dominance, wrong fade side, failed reconciliation,
current-price leakage beyond frozen Friday open, late/repeated entry, wrong
Friday lifecycle, nondeterminism, invalid risk mode, or an unusable standard-
Thursday proxy. Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
