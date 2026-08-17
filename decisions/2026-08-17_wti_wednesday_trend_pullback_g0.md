# G0 Decision — QM5_41046 WTI Wednesday Counter-Move / Slow-Trend Re-entry

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_wti_wednesday_trend_pullback_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41046_wti-wed-trend-pb_card.md`.

## Identity

- EA ID: `QM5_41046`, atomically allocated in commit `33dda3a60`
- slug: `wti-wed-trend-pb`
- strategy ID: `EIA-MOP-WTI-WEDTRENDPB-2026_S01`
- source approval commit: `96f02558c`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, planned magic `410460000`
- mechanic: after an exact completed standard Wednesday, require strict sign
  opposition between the completed event-day return and a separate 252-
  session trend ending Tuesday, enter Thursday in the slow-trend direction,
  and close next D1

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event identity and a
  complete-read peer-reviewed JFE trend lineage explicitly including WTI. No
  source validates the conjunction, WTI-specific result, or CFD translation.
- R2 `PASS`: exact weekdays, label normalization, separate completed endpoints,
  strict opposition, slow-trend direction, attempt persistence, grace, fixed
  risk, hard stop, spread cap, and next-D1 exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XTIUSD.DWX` D1 OHLC and
  MT5 state supply every runtime input; energy-label normalization remains an
  explicit carrier risk.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,533 registry rows and 625 root cards. It found
no exact identity and surfaced three nonidentical fuzzy matches. Manual review
separates this candidate from the cross-horizon agreement continuation in
`QM5_41045`, the Wednesday opposed-flow fade in `QM5_41041`, the monthly
counter-move in `QM5_20239`, the pre-event Wednesday trend entry in
`QM5_20154`, the range-expansion aftershock in `QM5_12590`, the M30 WPSR
sequences in `QM5_20133/20134`, and the incumbent oscillator in `QM5_12567`.

Verdict:
`CLEAN_AFTER_EXACT_AND_MANUAL_FAMILY_REVIEW_WITH_THREE_NONIDENTICAL_FUZZY_MATCHES`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and planned magic `410460000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Thursday plus completed Wednesday, Tuesday, and Monday at
  exact calendar offsets one, two, and three, with no substitution;
- first-Thursday decision within 180 minutes and one durable `yyyymmdd`
  attempt persisted before every fallible gate;
- `ln(WednesdayClose / TuesdayClose)` as the event return;
- `ln(TuesdayClose / Close252SessionsBeforeTuesday)` as the slow state, with
  Wednesday excluded from that state;
- strict nonzero sign opposition and entry in the slow-trend direction;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.0 * ATR(20,D1)` hard stop, no target, and 1,500-point spread
  ceiling;
- both news axes OFF, first-later-D1 strategy exit, three-day stale repair, and
  framework Friday close ON as fail-safe; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before Q02 handoff.

No inventory value, forecast, return-magnitude threshold, volatility signal
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
year, nonpositive governed economics, wrong weekday or endpoints, Wednesday
leakage into the slow state, non-opposed signs, wrong side, late or repeated
entry, wrong lifecycle, invalid risk mode, or nondeterminism. Q09 alone may
establish realized book correlation.

This decision excludes live, demo, shadow, stress, and optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
