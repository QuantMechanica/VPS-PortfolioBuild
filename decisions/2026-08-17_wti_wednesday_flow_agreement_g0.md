# G0 Decision — QM5_41042 WTI Standard-Wednesday Strict Flow-Agreement Continuation

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_wti_wednesday_flow_agreement_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41042_wti-wed-flow-agree_card.md`.

## Identity

- EA ID: `QM5_41042`, allocated in commit `7141ab818`
- slug: `wti-wed-flow-agree`
- strategy ID: `EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026_S01`
- source approval commit: `65df03e03`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, planned magic `410420000`
- mechanic: after an exact completed standard Wednesday, require strict sign
  agreement between close-to-open and open-to-close flows, follow the
  completed total on Thursday, and close at the next D1 boundary

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete OWNER-supplied Tier-A Williams decomposition, and a complete-paper
  peer-reviewed JFE futures-continuation source. No source validates the exact
  conjunction, and the JFE horizon is longer than one D1 session.
- R2 `PASS`: exact weekdays, energy-label normalization, completed endpoints,
  strict agreement, reconciliation, continuation side, attempt persistence,
  grace, fixed risk, hard stop, spread cap, and next-D1 exit are mechanical.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 OHLC and MT5 state supply every
  runtime input.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,529 registry rows and 625 flat card files. It
found no exact identity and surfaced the expected family for manual review:

- unlike `QM5_41029`, this identity forms from one standard Wednesday, enters
  Thursday, and exits next D1 instead of forming over a full week and holding
  Monday-Friday;
- unlike `QM5_41034`, it has no completed-month aggregation or month hold;
- unlike `QM5_41041`, it requires component agreement and follows the total
  rather than requiring opposition/session dominance and fading the total;
- unlike `QM5_20154`, it is symmetric and has no 252-D1 trend state;
- unlike `QM5_41024`, it evaluates every eligible Thursday from one completed
  Wednesday rather than only the first Wednesday from a prior-month sign; and
- unlike `QM5_12567`, it has no oscillator or long-only pullback logic.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and registered magic `410420000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Thursday plus completed Wednesday, Tuesday, and Monday at
  exact calendar offsets one, two, and three, with no substitution;
- first-Thursday decision within 180 minutes and one durable `yyyymmdd`
  attempt persisted before every fallible gate;
- completed Wednesday overnight and session log flows, strict same-sign
  agreement, and `1e-10` reconciliation to the Tuesday-close/Wednesday-close
  return;
- positive total maps to BUY and negative maps to SELL;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.0 * ATR(20,D1)` hard stop, no target, and 1,500-point spread
  ceiling;
- both news axes OFF, next-D1 strategy exit, three-day stale repair, and
  framework Friday close ON at broker hour 21; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before Q02 handoff.

No inventory number, event calendar file, magnitude threshold, volatility
signal gate, moving mean, oscillator, range, tail, breakout, season selector,
external runtime input, retry, scale-in, grid, martingale, pyramid,
optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count is below the governed ceiling. It does not authorize manual
tester dispatch or tester control.

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than
five/year, nonpositive governed economics, wrong weekday or endpoints,
component opposition, wrong continuation side, failed reconciliation,
current-bar leakage, late or repeated entry, wrong lifecycle, invalid risk
mode, nondeterminism, or an unusable standard-Wednesday proxy. Q09 alone may
establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
