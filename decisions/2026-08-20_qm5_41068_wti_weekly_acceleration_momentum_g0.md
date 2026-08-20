# G0 Decision - QM5_41068 WTI Completed-Week Acceleration Momentum

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_wti_weekly_acceleration_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41068_wti-waccel-mom_card.md`.

## Identity

- EA ID: `QM5_41068`, allocated deterministically at commit `17fb34638`
- slug: `wti-waccel-mom`
- strategy ID: `MOP-WTI-WACCEL-MOM-2026_S01`
- source approval commit: `b6c50e85f`
- magic allocation commit: `574a9d70c`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410680000`
- mechanic: two adjacent completed WTI weekly returns must share a strict
  sign and the newest absolute move must be strictly larger; follow that sign
  for one broker week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_ACCELERATION_TRANSLATION_RISK`: a named-author,
  peer-reviewed JFE paper with DOI, complete-paper evidence, retrieval
  identity, and explicit WTI membership supplies own-return continuation
  lineage. The weekly horizon and same-sign acceleration gate are untested QM
  conditions and are disclosed as such.
- R2 `PASS`: uniform label normalization, exact first-week-bar clock, three
  consecutive completed week ends, two non-overlapping log returns, strict
  sign and magnitude state, newest-sign side, durable attempt, fixed risk,
  hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history and active slot-zero magic supply every runtime input. Q02 owns
  label, history, fill, density, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, close, logarithm, ATR risk plumbing,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema, prohibited-ML, and G0 lint: `PASS` on the approved card path.

## Duplicate Review

The canonical pre-allocation checker scanned 4,555 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates sign-handoff WTI `QM5_41065`, volatility-conditioned one-week WTI
momentum `QM5_13049` and `QM5_21503`, within-week dual-segment momentum
`QM5_41022`, weekly NR7 breakout `QM5_41061`, and the incumbent
multi-commodity cumulative-RSI2 pullback `QM5_12567`.

This card requires two separate full close-to-close broker-week returns to
agree, requires strict newest-magnitude acceleration, follows their sign, and
owns the next full broker week. Verdict:
`CLEAN_WTI_TWO_WEEK_SAME_SIGN_ACCELERATION_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and registered magic;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and all historical endpoints;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- three consecutive completed Monday-anchored week-end closes, two adjacent
  non-overlapping log returns, strict same sign, strict newest absolute-
  return acceleration, and newest-sign side;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No unconditional weekly fallback, opposed-sign, equal-magnitude, or
decelerating entry, oldest-sign or inverse side, current-week price,
overlapping endpoints, return threshold, oscillator, calendar/volatility/
volume filter, retry, external data, parameter sweep, target, trail, scale-in,
grid, martingale, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one WTI D1 `RISK_FIXED`
backtest set, strict Q01, and one paced target-only Q02 enqueue only if exact-
path tester count and host CPU are below governed ceilings. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/week/endpoint
state, opposed-sign or non-accelerating entry, wrong side, repeated attempt,
invalid risk mode, missing stop, wrong week lifecycle, or nondeterminism. Q09
alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.

