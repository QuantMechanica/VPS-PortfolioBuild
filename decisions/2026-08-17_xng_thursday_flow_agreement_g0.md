# G0 Decision — QM5_41043 XNG Standard-Thursday Strict Flow-Agreement Continuation

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xng_thursday_flow_agreement_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41043_xng-thu-flow-agree_card.md`.

## Identity

- EA ID: `QM5_41043`, allocated in commit `e4505d7e8`
- slug: `xng-thu-flow-agree`
- strategy ID: `EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026_S01`
- source approval commit: `0dcf4d10a`
- carrier: exact `XNGUSD.DWX`, D1, slot 0, planned magic `410430000`
- mechanic: after an exact completed standard Thursday, require strict sign
  agreement between close-to-open and open-to-close flows, follow the
  completed total on Friday, and close at the next D1 boundary

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete OWNER-supplied Tier-A Williams decomposition, and a complete-paper
  peer-reviewed JFE futures-continuation source that includes natural gas. No
  source validates the exact conjunction; the JFE horizon is longer and the
  Friday-to-next-D1 weekend translation is QM-defined.
- R2 `PASS`: exact weekdays, energy-label normalization, completed endpoints,
  strict agreement, reconciliation, continuation side, attempt persistence,
  grace, fixed risk, hard stop, spread cap, and next-D1 exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XNGUSD.DWX` D1 OHLC and
  MT5 state supply every runtime input; energy-label normalization remains an
  explicit carrier risk.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,530 registry rows and 625 flat card files. It
found no exact identity and surfaced the expected WTI flow-agreement family.
Manual review separates the proposed XNG carrier, Thursday storage clock,
Friday decision, and weekend-bearing next-D1 lifecycle from the WTI weekly,
monthly, and Wednesday-event relatives. Existing XNG Thursday systems are
unconditional calendar or slow-trend entries; storage M30 systems trade the
release window; `QM5_12567` is cumulative-RSI pullback logic.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XNGUSD.DWX` D1 slot 0 and planned magic `410430000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Friday plus completed Thursday, Wednesday, and Tuesday at
  exact calendar offsets one, two, and three, with no substitution;
- first-Friday decision within 180 minutes and one durable `yyyymmdd` attempt
  persisted before every fallible gate;
- completed Thursday overnight and session log flows, strict same-sign
  agreement, and `1e-10` reconciliation to the Wednesday-close/Thursday-close
  return;
- positive total maps to BUY and negative maps to SELL;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.5 * ATR(20,D1)` hard stop, no target, and 3,000-point spread
  ceiling;
- both news axes OFF, next-D1 strategy exit, four-day stale repair, and
  framework Friday close OFF; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before Q02 handoff.

No storage number, event calendar file, magnitude threshold, volatility signal
gate, moving mean, oscillator, range, tail, breakout, season selector, external
runtime input, retry, scale-in, grid, martingale, pyramid, optimization surface,
or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count is below the governed ceiling. It does not authorize manual
tester dispatch or tester control.

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday or endpoints, component
opposition, wrong continuation side, failed reconciliation, current-bar
leakage, late or repeated entry, wrong lifecycle, invalid risk mode,
nondeterminism, or an unusable standard-Thursday proxy. Q09 alone may establish
realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
