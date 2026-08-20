# G0 Decision - QM5_41070 WTI Completed-Week Deceleration Momentum

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_wti_weekly_deceleration_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41070_wti-wdecel-mom_card.md`.

## Identity

- EA ID: `QM5_41070`, allocated deterministically at commit `5c9b99117`
- slug: `wti-wdecel-mom`
- strategy ID: `MOP-WTI-WDECEL-MOM-2026_S01`
- source approval commit: `82b48303d`
- magic allocation commit: `bc55a9805`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410700000`
- mechanic: two adjacent completed WTI weekly returns must share a strict
  sign and the newest absolute move must be strictly smaller; follow their
  shared sign for one broker week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_DECELERATION_TRANSLATION_RISK`: a named-author,
  peer-reviewed JFE paper with DOI, complete-paper evidence, retrieval
  identity, and explicit WTI membership supplies own-return continuation
  lineage. The weekly horizon and same-sign deceleration gate are untested QM
  conditions and are disclosed as such.
- R2 `PASS`: uniform label normalization, exact first-week-bar clock, three
  consecutive completed week ends, two non-overlapping log returns, strict
  sign and magnitude state, shared-sign side, durable attempt, fixed risk,
  hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history and active slot-zero magic supply every runtime input. Q02 owns
  label, history, fill, density, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, close, logarithm, ATR risk plumbing,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema, prohibited-ML, and G0 lint: `PASS` is required on the approved
  card path before Development begins.

## Duplicate Review

The canonical pre-allocation checker scanned 4,557 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates strict acceleration `QM5_41068`, opposed-sign smaller-countermove
re-entry `QM5_41069`, opposed-sign newest-direction handoff `QM5_41065`,
gold/silver relative-basket decay reversion `QM5_41066`, monthly pullback
`QM5_20239`, one-return volatility-conditioned WTI `QM5_13049` /
`QM5_21503`, and incumbent cumulative-RSI2 commodity pullback `QM5_12567`.

This card requires two separate full close-to-close broker-week returns to
agree, requires strict newest-magnitude deceleration, follows their shared
sign, and owns the next full broker week. Verdict:
`CLEAN_WTI_TWO_WEEK_SAME_SIGN_DECELERATION_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and registered magic;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and all historical endpoints;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- three consecutive completed Monday-anchored week-end closes, two adjacent
  non-overlapping log returns, strict same sign, strict newest absolute-
  return deceleration, and shared-sign side;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No unconditional weekly fallback, opposed-sign, equal-magnitude, or
accelerating entry, oldest-sign or inverse side, current-week price,
overlapping endpoints, return threshold, oscillator, calendar/volatility/
volume filter, retry, external data, parameter sweep, target, trail, scale-in,
grid, martingale, or after-result rescue is approved.

## Portfolio Claim Boundary

The candidate supplies direct WTI physical-energy exposure outside the
certified XAU/SP500/NDX/XNG book and differs from certified `QM5_12567`'s
long-only cumulative-RSI2 pullback. Neither fact proves low correlation. Q09
alone may establish realized overlap; no portfolio admission occurs at G0.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one WTI D1 `RISK_FIXED`
backtest set, strict Q01, and one paced target-only Q02 enqueue only if exact-
path tester count and host CPU are below governed ceilings. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/week/endpoint
state, opposed-sign or non-decelerating entry, wrong side, repeated attempt,
invalid risk mode, missing stop, wrong week lifecycle, or nondeterminism. Q09
alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.

