# G0 Decision — QM5_41048 XNG Standard-Thursday Event / Slow-Trend Agreement

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xng_thursday_trend_agreement_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41048_xng-thu-trend-agree_card.md`.

## Identity

- EA ID: `QM5_41048`, atomically allocated in commit `7da2ce5bf`
- slug: `xng-thu-trend-agree`
- strategy ID: `EIA-MOP-XNG-THUTRENDAGREE-2026_S01`
- source approval commit: `91bf3d7d4`
- carrier: exact `XNGUSD.DWX`, D1, slot 0, planned magic `410480000`
- mechanic: after an exact completed standard Thursday, require strict sign
  agreement between the completed event-day return and a separate 252-session
  trend ending Wednesday, enter Friday in the common direction, and close next
  D1

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event identity and a
  complete-read peer-reviewed JFE trend lineage explicitly including natural
  gas. No source validates the conjunction, XNG-specific result, or CFD
  translation.
- R2 `PASS`: exact weekdays, label normalization, separate completed endpoints,
  strict agreement, common-sign direction, attempt persistence, grace, fixed
  risk, hard stop, spread cap, and next-D1 exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XNGUSD.DWX` D1 OHLC and
  MT5 state supply every runtime input; energy-label normalization remains an
  explicit carrier risk.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,535 registry rows and 625 root cards and
returned `CLEAN`. Manual review separates this candidate from the
event/trend-opposition sibling in `QM5_41047`, the pre-event short-only XNG
Thursday carrier in `QM5_20163`, component-flow systems in `QM5_41043/41044`,
the reaction-magnitude aftershock in `QM5_12584`, the M30 storage sequence in
`QM5_20124/20128/20132`, and the incumbent oscillator in `QM5_12567`.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_COMPLETED_EVENT_RETURN_AND_PRE_EVENT_TWELVE_MONTH_TREND_AGREEMENT_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XNGUSD.DWX` D1 slot 0 and planned magic `410480000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Friday plus completed Thursday, Wednesday, and Tuesday at
  exact calendar offsets one, two, and three, with no substitution;
- first-Friday decision within 180 minutes and one durable `yyyymmdd` attempt
  persisted before every fallible gate;
- `ln(ThursdayClose / WednesdayClose)` as the event return;
- `ln(WednesdayClose / Close252SessionsBeforeWednesday)` as the slow state,
  with Thursday excluded from that state;
- strict nonzero sign agreement and entry in the common direction;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.5 * ATR(20,D1)` hard stop, no target, and 3,000-point spread
  ceiling;
- both news axes OFF, first-later-D1 strategy exit, four-day stale repair, and
  framework Friday close OFF to preserve the weekend hold; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before Q02 handoff.

No storage value, forecast, return-magnitude threshold, volatility signal
gate, moving mean, oscillator, range expansion, breakout, season selector,
external runtime input, retry, scale-in, grid, martingale, pyramid,
optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count is below the governed ceiling. It does not authorize manual
tester dispatch or tester control.

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than eight per
year, nonpositive governed economics, wrong weekday or endpoints, Thursday
leakage into the slow state, sign disagreement, wrong side, late or repeated
entry, wrong lifecycle, invalid risk mode, or nondeterminism. Q09 alone may
establish realized book correlation.

This decision excludes live, demo, shadow, stress, and optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
