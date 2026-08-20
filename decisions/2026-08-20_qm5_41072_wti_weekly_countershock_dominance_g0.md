# G0 Decision - QM5_41072 WTI Completed-Week Countershock Dominance

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_wti_weekly_countershock_dominance_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41072_wti-wcounter-dom_card.md`.

## Identity

- EA ID: `QM5_41072`, allocated deterministically at commit `c8ca0aa93`
- slug: `wti-wcounter-dom`
- strategy ID: `MOP-WTI-WCOUNTER-DOM-2026_S01`
- source approval commit: `83b83ee3a`
- magic allocation commit: `950a4d98b`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410720000`
- mechanic: three adjacent completed WTI weekly returns must follow an
  outer-sign / opposed-middle / restored-outer-sign path, with the middle
  absolute move strictly larger than both outer moves combined; follow the
  middle and cumulative-three-week sign for one broker week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK`: a named-author, peer-reviewed
  JFE paper with DOI, complete-paper evidence, retrieval identity, and explicit
  WTI membership supplies own-return continuation lineage. The weekly horizon,
  three-week path, and strict combined-dominance gate are untested QM
  conditions and are disclosed as such.
- R2 `PASS`: uniform label normalization, exact first-week-bar clock, four
  consecutive completed week ends, three non-overlapping log returns, strict
  chronological signs, combined dominance, middle/net-sign side, durable
  attempt, fixed risk, hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history and active slot-zero magic supply every runtime input. Q02 owns
  label, history, fill, density, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, close, logarithm, ATR risk plumbing,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema, prohibited-ML, and G0 lint: `PASS` is required on the approved
  card path before Development begins.

## Duplicate Review

The canonical pre-allocation checker scanned 4,559 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates newest-resumption dominance `QM5_41071`, generic two-week handoff
`QM5_41065`, immediate smaller-counterweek pullback `QM5_41069`, same-sign
acceleration/deceleration `QM5_41068` / `QM5_41070`, monthly handoff
`QM5_41064`, multi-month sign-run `QM5_20273`, and one-return
volatility-conditioned WTI `QM5_13049` / `QM5_21503`.

This card requires a third older week whose sign is restored after an opposed
middle week, requires the middle move to exceed the sum of both outer moves,
proves that the three-week cumulative return retains the middle sign, follows
that sign opposite the newest week, and owns the next full broker week.
Verdict:
`CLEAN_WTI_THREE_WEEK_COUNTERSHOCK_COMBINED_DOMINANCE_AFTER_MANUAL_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and registered magic;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and all historical endpoints;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- four consecutive completed Monday-anchored week-end closes, three adjacent
  non-overlapping log returns, strict outer-sign equality, strict opposed
  middle, strict middle-over-summed-outer absolute-return dominance, and
  middle/net-sign side;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No unconditional weekly fallback, outer-sign mismatch, non-opposed middle,
equal or insufficient middle move, newest-sign side, current-week price,
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

Q02 must retire on zero trades, fewer than two completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/week/endpoint
state, wrong sign path, absent strict combined dominance, wrong side, repeated
attempt, invalid risk mode, missing stop, wrong week lifecycle, or
nondeterminism. Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.

