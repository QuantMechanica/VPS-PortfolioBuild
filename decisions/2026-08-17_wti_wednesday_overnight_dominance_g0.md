# G0 Decision - QM5_41049 WTI Standard-Wednesday Overnight-Dominant Flow Continuation

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_wti_wednesday_overnight_dominance_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41049_wti-wed-overnight-dom_card.md`.

## Identity

- EA ID: `QM5_41049`, allocated in commit `ddcc7b96c`
- slug: `wti-wed-overnight-dom`
- strategy ID: `EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026_S01`
- source approval commit: `4ab03d72a`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, registered magic `410490000`
  in commit `26abbec15`
- mechanic: at the first genuine broker Thursday, decompose the exact
  completed Wednesday into Tuesday-close-to-Wednesday-open and Wednesday-
  open-to-close flows; require strict opposition and strict overnight
  dominance; follow the reconciled Wednesday total; close at the next D1
  boundary

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, complete OWNER-supplied Williams price-flow extraction, and a
  complete-paper peer-reviewed own-return continuation study that explicitly
  includes WTI. No source tests this conjunction, and the paper's horizons are
  materially longer than one D1 interval.
- R2 `PASS`: exact weekdays, energy-label normalization, completed endpoints,
  strict opposition, strict overnight dominance, reconciliation,
  continuation side, attempt persistence, entry grace, fixed risk, hard
  stop, spread cap, and next-D1 exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XTIUSD.DWX` D1 OHLC,
  quotes, broker calendar, positions, deal history, and terminal state supply
  every runtime input. The price-only standard-Wednesday classification
  remains falsifiable.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, hedge, or pyramid.

## Duplicate Review

The canonical pre-allocation checker scanned 4,536 registry rows and 625 card
files and returned `CLEAN` with no exact or fuzzy identity. Manual review
confirms:

- `QM5_41041_wti-wed-flow-fade` admits only strict session dominance and
  fades the completed total; this card admits the disjoint strict overnight-
  dominant state and follows it, with equality excluded from both;
- `QM5_41042_wti-wed-flow-agree` requires component sign agreement, while
  this card requires strict opposition;
- `QM5_41033_wti-flow-dom` and `QM5_41036_wti-mflow-dom` aggregate complete
  weeks or months, not one event-clock Wednesday and the following D1;
- `QM5_12784_progo-xti` uses crossings of smoothed fourteen-day flow lines,
  not unsmoothed exact-session components with a fixed next-D1 lifecycle;
- `QM5_41045_wti-wed-trend-agree` and `QM5_41046_wti-wed-trend-pb` compare
  the whole Wednesday return with a 252-session trend and do not decompose
  Wednesday; and
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_OPPOSED_FLOW_STRICT_OVERNIGHT_DOMINANCE_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and registered magic `410490000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Thursday plus completed Wednesday, Tuesday, and Monday at
  exact calendar offsets one, two, and three, with no substitution;
- first-Thursday decision within 180 minutes and one durable `yyyymmdd`
  attempt persisted before every fallible gate;
- completed Wednesday overnight and session log flows, strict opposition,
  strict `abs(overnight_flow) > abs(session_flow)`, and `1e-10`
  reconciliation to the Tuesday-close/Wednesday-close return;
- positive reconciled total maps to BUY and negative maps to SELL;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point
  spread ceiling;
- both news axes OFF, next-D1 strategy exit, three-day stale repair, and
  framework Friday close ON at broker hour 21; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No inventory number, event calendar file, magnitude threshold, dominance
ratio threshold, volatility signal gate, moving mean, oscillator, range,
tail, breakout, season selector, external runtime input, retry, scale-in,
grid, martingale, hedge, pyramid, optimization surface, or after-result rescue
is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count is below the governed ceiling. It does not authorize a
manual tester dispatch or tester control.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong weekday/endpoints, component agreement,
absent strict overnight dominance, wrong continuation side, failed
reconciliation, current-bar leakage, late/repeated entry, wrong lifecycle,
invalid risk mode, nondeterminism, or an unusable standard-Wednesday proxy.
Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
