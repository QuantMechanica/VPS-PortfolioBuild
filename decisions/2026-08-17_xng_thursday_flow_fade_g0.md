# G0 Decision — QM5_41044 XNG Standard-Thursday Session-Dominant Flow Fade

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xng_thursday_flow_fade_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41044_xng-thu-flow-fade_card.md`.

## Identity

- EA ID: `QM5_41044`, atomically allocated in commit `9ed38e874`
- slug: `xng-thu-flow-fade`
- strategy ID: `EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026_S01`
- source approval commit: `fcccf5407`
- carrier: exact `XNGUSD.DWX`, D1, slot 0, planned magic `410440000`
- mechanic: after an exact completed standard Thursday, require strict
  opposition between close-to-open and open-to-close flow, require the session
  component to dominate, fade the completed total on Friday, and close at the
  next D1 boundary

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one canonical composite source ID
  joins official EIA event lineage, a complete OWNER-supplied Tier-A Williams
  decomposition, and peer-reviewed commodity-reversal lineage. The governed
  academic record is partial, its universe is not XNG, and no source validates
  the exact conjunction.
- R2 `PASS`: exact weekdays, energy-label normalization, completed endpoints,
  strict opposition, strict session dominance, reconciliation, contrarian
  side, attempt persistence, grace, fixed risk, hard stop, spread cap, and
  next-D1 exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XNGUSD.DWX` D1 OHLC and
  MT5 state supply every runtime input; energy-label normalization remains an
  explicit carrier risk.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,531 registry rows and 625 root card files and
returned `CLEAN`. Manual review separates this candidate from the strict-flow
agreement continuation in `QM5_41043`, the unconditional Thursday short in
`QM5_12819`, the M30 storage-release systems in `QM5_20124/20128/20132`, the
monthly XNG flow systems in `QM5_41037/41038`, and the incumbent long-only
cumulative-RSI2 pullback in `QM5_12567`. The WTI sibling `QM5_41041` uses a
different carrier, Wednesday petroleum clock, Thursday entry, and
non-weekend lifecycle.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XNGUSD.DWX` D1 slot 0 and planned magic `410440000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Friday plus completed Thursday, Wednesday, and Tuesday at
  exact calendar offsets one, two, and three, with no substitution;
- first-Friday decision within 180 minutes and one durable `yyyymmdd` attempt
  persisted before every fallible gate;
- completed Thursday overnight and session log flows, strict opposition,
  strict session dominance, and `1e-10` reconciliation to the
  Wednesday-close/Thursday-close return;
- positive completed total maps to SELL and negative maps to BUY;
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

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday or endpoints, component
agreement, absent strict session dominance, wrong contrarian side, failed
reconciliation, current-bar leakage, late or repeated entry, wrong lifecycle,
invalid risk mode, nondeterminism, or an unusable standard-Thursday proxy. Q09
alone may establish realized book correlation.

This decision excludes live, demo, shadow, stress, and optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
