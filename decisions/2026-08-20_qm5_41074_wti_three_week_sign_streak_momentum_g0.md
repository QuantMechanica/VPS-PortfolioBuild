# G0 Decision - QM5_41074 WTI Fresh Three-Week Sign-Streak Momentum

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_wti_three_week_sign_streak_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41074_wti-wstreak3-mom_card.md`.

## Identity

- EA ID: `QM5_41074`, allocated deterministically at commit `15884df96`
- slug: `wti-wstreak3-mom`
- strategy ID: `MOP-WTI-WSTREAK3-MOM-2026_S01`
- source approval commit: `c0fe1591d`
- magic allocation commit: `b4ef324e0`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410740000`
- mechanic: reconstruct five consecutive completed broker-week ending closes;
  require the newest three adjacent weekly returns to have one strict common
  sign and the preceding return to have the strict opposite sign; follow the
  fresh three-week streak direction for one broker week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK`: a named-author, peer-reviewed
  JFE paper with DOI, complete-paper evidence, retrieval identity, and
  explicit WTI membership supplies own-return continuation lineage. The
  weekly horizon and fresh three-week transition are untested QM conditions
  and are disclosed as such.
- R2 `PASS`: uniform label normalization, exact first-week-bar clock, five
  consecutive completed weekly endpoints, bounded session counts, four
  adjacent return formulas, strict `-+++` / `+---` state, durable attempt,
  fixed risk, hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history and active slot-zero magic supply every runtime input. Q02 owns
  label, history, fill, density, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, completed close, logarithm, comparison,
  ATR risk plumbing, quote, position, deal, and terminal state only; no banned
  signal, external runtime feed, adaptive fit, grid, martingale, scale-in, or
  pyramid.
- Card schema, prohibited-method, and G0 lint: `PASS` is required on the
  approved card path before Development begins.

## Duplicate Review

The canonical pre-allocation checker scanned 4,561 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates the immediate weekly handoff `QM5_41065`, same-sign magnitude
acceleration/deceleration `QM5_41068` / `QM5_41070`, opposed-week pullback /
resumption / countershock `QM5_41069` / `QM5_41071` / `QM5_41072`, split-week
agreement `QM5_41022`, twelve-month sign-path `QM5_20273`, and cumulative-RSI2
`QM5_12567`.

This card waits for the first completed three-week same-sign run after a
strictly opposed predecessor, ignores return magnitudes, consumes one attempt
at the next boundary, follows the streak, and owns one full broker week.
Verdict:
`CLEAN_WTI_FRESH_THREE_WEEK_SIGN_STREAK_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and registered magic;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and all historical closes;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- five consecutive completed Monday-anchored week packages with three to five
  strictly ordered valid sessions each;
- four adjacent close-to-close log returns, strict `-+++` buy or `+---` sell,
  and no magnitude comparison;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No unconditional weekly fallback, zero-return acceptance, rolling re-entry
after a fourth same-sign week, changed streak length, magnitude threshold,
current-week OHLC signal, SMA, oscillator, calendar/volume filter, retry,
external data, parameter sweep, target, trail, scale-in, grid, martingale, or
after-result rescue is approved.

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
post-warm-up year, nonpositive governed economics, wrong label/week/endpoint
state, invalid session count, wrong sign transition or side, repeated attempt,
invalid risk mode, missing stop, wrong week lifecycle, or nondeterminism. Q09
alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.

