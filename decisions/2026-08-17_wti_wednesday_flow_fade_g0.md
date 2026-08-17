# G0 Decision - QM5_41041 WTI Standard-Wednesday Session-Dominant Flow Fade

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_wti_wednesday_flow_fade_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41041_wti-wed-flow-fade_card.md`.

## Identity

- EA ID: `QM5_41041`, allocated in commit `99c3dc896`
- slug: `wti-wed-flow-fade`
- strategy ID: `EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026_S01`
- source approval commit: `4d5611a10`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, planned magic `410410000`
- mechanic: at the first genuine broker Thursday, decompose the exact
  completed Wednesday into Tuesday-close-to-Wednesday-open and Wednesday-
  open-to-close flows; require strict opposition and strict session
  dominance; fade the completed Wednesday total; close at the next D1
  boundary

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: approved official EIA event
  lineage, complete OWNER-supplied Tier-A Williams decomposition, and a named
  peer-reviewed commodity-reversal publication. The Yang local record is not
  a full-paper receipt and no source validates the conjunction.
- R2 `PASS`: exact weekdays, energy-label normalization, completed endpoints,
  strict opposition, strict session dominance, reconciliation, fade side,
  attempt persistence, entry grace, fixed risk, hard stop, spread cap, and
  next-D1 exit are mechanical.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 OHLC, quotes, broker calendar,
  positions, deal history, and terminal state supply every runtime input.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,528 registry rows and 625 card files and
returned `CLEAN` with no exact or fuzzy identity. Manual review confirms:

- unlike `QM5_12590`, the card has no range/body/tail/SMA-stretch state and
  exits next D1 rather than after a multi-day reversion window;
- unlike `QM5_12579` and `QM5_12988`, it neither follows one event move nor
  confirms two event moves with moving-average/channel state;
- unlike `QM5_20133` and `QM5_20134`, it uses completed D1 close/open
  components and a next-day hold rather than an M30 release sequence and
  same-session exit;
- unlike `QM5_41029`, `QM5_41032`, and `QM5_41033`, it forms from one exact
  Wednesday, enters Thursday, fades a session-dominant disagreement, and
  exits next D1 rather than forming over a full week and trading Monday-Friday;
- unlike `QM5_41040`, it is a direct WTI position rather than a synchronized
  XAU/XAG relative basket; and
- unlike `QM5_12567`, it has no oscillator or long-only pullback logic.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and registered magic `410410000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Thursday plus completed Wednesday, Tuesday, and Monday at
  exact calendar offsets one, two, and three, with no substitution;
- first-Thursday decision within 180 minutes and one durable `yyyymmdd`
  attempt persisted before every fallible gate;
- completed Wednesday overnight and session log flows, strict opposition,
  strict `abs(session_flow) > abs(overnight_flow)`, and `1e-10`
  reconciliation to Tuesday-close/Wednesday-close return;
- positive completed Wednesday total maps to SELL and negative maps to BUY;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both news axes OFF, next-D1 strategy exit, three-day stale repair, and
  framework Friday close ON at broker hour 21; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No inventory number, event calendar file, magnitude threshold, dominance
ratio threshold, volatility signal gate, moving mean, oscillator, range,
tail, breakout, season selector, external runtime input, retry, scale-in,
grid, martingale, pyramid, optimization surface, or after-result rescue is
approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count is below the governed ceiling. It does not authorize a
manual tester dispatch or tester control.

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong weekday/endpoints, component agreement,
absent session dominance, wrong fade side, failed reconciliation, current-bar
leakage, late/repeated entry, wrong lifecycle, invalid risk mode,
nondeterminism, or an unusable standard-Wednesday proxy. Q09 alone may
establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
