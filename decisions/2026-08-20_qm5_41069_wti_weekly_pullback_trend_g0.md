# G0 Decision - QM5_41069 WTI Completed-Week Pullback Trend

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_wti_weekly_pullback_trend_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41069_wti-wpull-trend_card.md`.

## Identity

- EA ID: `QM5_41069`, allocated deterministically at commit `af2e427b6`
- slug: `wti-wpull-trend`
- strategy ID: `MOP-WTI-WPULL-TREND-2026_S01`
- source approval commit: `c655c2d6a`
- magic allocation commit: `734c0f565`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410690000`
- mechanic: two adjacent completed WTI weekly returns with strict sign
  opposition and a strictly smaller newest countermove, followed in the older
  sign direction for one broker week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_PULLBACK_TRANSLATION_RISK`: a named-author,
  peer-reviewed JFE paper with DOI, complete-paper evidence, retrieval
  identity, and explicit WTI membership supplies own-return continuation
  lineage. The weekly horizon and smaller-countermove re-entry gate are
  untested QM conditions and are disclosed as such.
- R2 `PASS`: uniform label normalization, exact first-week-bar clock, three
  consecutive completed week ends, two non-overlapping log returns, strict
  sign opposition, strict smaller newest magnitude, older-sign side, durable
  attempt, fixed risk, hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history and active slot-zero magic supply every runtime input. Q02 owns
  label, history, fill, density, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, close, logarithm, ATR risk plumbing,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema and prohibited-ML lint: `PASS` is required on the approved card
  path before Development begins.

## Duplicate Review

The canonical pre-allocation checker scanned 4,556 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates newest-sign weekly handoff `QM5_41065`, same-sign acceleration
`QM5_41068`, twelve-month/one-month pullback `QM5_20239`, Wednesday event
pullback `QM5_41046`, Friday/containing-week fade `QM5_41051`, and one-return
volatility-conditioned `QM5_13049` / `QM5_21503`.

This card requires two separate full close-to-close broker-week returns to
disagree, requires the newer move to be strictly smaller, follows the older
return, and owns the next full broker week. Verdict:
`CLEAN_WTI_TWO_WEEK_SMALLER_COUNTERMOVE_TREND_REENTRY_AFTER_MANUAL_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and registered magic;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and all historical endpoints;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- three consecutive completed Monday-anchored week-end closes, two adjacent
  non-overlapping log returns, strict sign opposition, strict smaller newest
  magnitude, and older-sign direction;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No unconditional weekly fallback, same-sign entry, equal or larger newest
move, newest-sign side, current-week price, overlapping endpoints, return
threshold, oscillator, calendar/volatility filter, retry, external data,
parameter sweep, target, trail, scale-in, grid, martingale, or after-result
rescue is approved.

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
state, same-sign, non-smaller, or wrong-side entry, repeated attempt, invalid
risk mode, missing stop, wrong week lifecycle, or nondeterminism. Q09 alone
may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
