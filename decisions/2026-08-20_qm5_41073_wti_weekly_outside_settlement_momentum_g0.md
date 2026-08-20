# G0 Decision - QM5_41073 WTI Completed-Week Outside-Settlement Momentum

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_wti_weekly_outside_settlement_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41073_wti-woutside-settle_card.md`.

## Identity

- EA ID: `QM5_41073`, allocated deterministically at commit `1990ead14`
- slug: `wti-woutside-settle`
- strategy ID: `MOP-WTI-WOUTSIDE-SETTLE-2026_S01`
- source approval commit: `c276afbdd`
- magic allocation commit: `c6e44efa9`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410730000`
- mechanic: aggregate two consecutive completed broker-week OHLC packages;
  require the newer week to have a strict higher high and lower low, settle
  beyond the matching parent extreme, close in its own matching outer
  quartile, and agree with its own first-open-to-last-close sign; follow that
  direction for one broker week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_RANGE_TRANSLATION_RISK`: a named-author,
  peer-reviewed JFE paper with DOI, complete-paper evidence, retrieval
  identity, and explicit WTI membership supplies own-return continuation
  lineage. The weekly horizon and outside-settlement state are untested QM
  conditions and are disclosed as such.
- R2 `PASS`: uniform label normalization, exact first-week-bar clock, two
  consecutive completed weekly OHLC packages, bounded session counts, strict
  outside range, own-week direction, parent settlement, strict close-location
  boundary, durable attempt, fixed risk, hard stop, spread, and lifecycle are
  mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history and active slot-zero magic supply every runtime input. Q02 owns
  label, history, fill, density, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, completed OHLC, arithmetic, ATR risk
  plumbing, quote, position, deal, and terminal state only; no banned signal,
  external runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema, prohibited-ML, and G0 lint: `PASS` is required on the approved
  card path before Development begins.

## Duplicate Review

The canonical pre-allocation checker scanned 4,560 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates the existing outside-week fade `QM5_13095`, seven-week NR7 breakout
`QM5_41061`, current-week opening-range breakout `QM5_12965`, adjacent-week
return acceleration/deceleration `QM5_41068` / `QM5_41070`, return-path
handoff/pullback/resumption/countershock `QM5_41065` / `QM5_41069` /
`QM5_41071` / `QM5_41072`, and cumulative-RSI2 `QM5_12567`.

This card enters at the first new-week boundary, not after a separate reversal
or current-week breakout; requires strict two-sided completed range expansion;
requires the completed close to remain beyond the parent extreme and in the
matching outer quartile; follows rather than fades that settlement; and owns
the next full broker week. Verdict:
`CLEAN_WTI_COMPLETED_OUTSIDE_WEEK_SETTLEMENT_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and registered magic;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and all historical OHLC;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- two consecutive completed Monday-anchored weekly OHLC aggregates with three
  to five strictly ordered valid sessions each;
- strict newer-week higher high and lower low, first-open-to-last-close sign,
  close beyond the matching parent extreme, and strict `>0.75` / `<0.25`
  directional close-location state;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No unconditional weekly fallback, non-outside week, inside-parent settlement,
wrong own-week sign, equality at an extreme or quartile boundary, current-week
OHLC signal, SMA, return/ATR magnitude signal, oscillator, calendar/volume
filter, retry, external data, parameter sweep, target, trail, scale-in, grid,
martingale, or after-result rescue is approved.

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

Q02 must retire on zero trades, fewer than three completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/week/OHLC
state, invalid session count, non-outside entry, wrong own-week sign, absent
parent settlement, non-extreme or equality close, wrong side, repeated
attempt, invalid risk mode, missing stop, wrong week lifecycle, or
nondeterminism. Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.

