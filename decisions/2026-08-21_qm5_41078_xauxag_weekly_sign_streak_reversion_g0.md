# G0 Decision - QM5_41078 XAU/XAG Weekly Sign-Streak Reversion

Date: 2026-08-21

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-21_xauxag_weekly_sign_streak_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41078_xauxag-wstreak3-rv_card.md`.

## Identity

- EA ID: `QM5_41078`, allocated deterministically at commit `a9f8e1214`
- slug: `xauxag-wstreak3-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026_S01`
- source approval commit: `83ec155ac`
- intended host: exact `XAUUSD.DWX`, D1, slot 0, magic `410780000`
- intended companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410780001`
- logical symbol: `QM5_41078_XAU_XAG_WSTREAK3_RV_D1`
- mechanic: fade the first completion of three strict same-sign weekly gold-
  minus-silver returns after one strict opposite predecessor, for one week

Active slot-zero and slot-one magic allocation plus resolver regeneration are
mandatory before Development invokes the build skill.

## Gate Findings

- R1 `PASS_WITH_WEEKLY_STREAK_REVERSION_TRANSLATION_RISK`: one bounded child
  source carries a named-author peer-reviewed DOI record plus official
  exchange carrier evidence. The weekly fresh-streak fade is an untested QM
  condition and is disclosed as such.
- R2 `PASS`: exact first-week-bar clock, synchronized endpoints, chronological
  relative returns, strict fresh-streak state, contrarian side, durable
  attempt, aggregate risk, equal-notional target, hard stops, spreads, and
  lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 routes supply every runtime input. Q02 owns paired history, fills,
  costs, density, and continuous-CFD basis falsification.
- R4 `PASS`: deterministic timestamp, price, logarithm, comparison, ATR,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema and prohibited-signal lint must pass on the approved card path
  before implementation.

## Duplicate Review

The canonical pre-allocation checker scanned 4,565 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates rolling ratio/residual systems, daily five-return exhaustion,
monthly cross-sectional rank systems, weekly/monthly flow decomposition,
opposed weekend gaps, weekly NR7 breakout, and every two-return weekly
sign/magnitude variant through `QM5_41077`.

This card alone requires five synchronized completed broker-week endpoint
pairs, four chronological relative returns, exact fresh `-+++` or `+---`
state, and a contrarian one-week package. The closest path sibling,
`QM5_41074`, follows the same fresh sign topology on outright WTI; this card
fades it on a paired XAU/XAG carrier. Verdict:
`CLEAN_XAUXAG_FRESH_THREE_WEEK_SIGN_STREAK_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card after active magic allocation
with:

- exact XAU D1 host slot 0 and XAG D1 companion slot 1 under governed magics
  and one logical basket manifest;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- five consecutive completed synchronized Monday-anchored week-end pairs,
  three to five sessions per week, four chronological gold-minus-silver log
  returns, strict fresh `-+++` or `+---` state, and contrarian package side;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one aggregate `RISK_FIXED=1000` budget, equal absolute notional target,
  frozen `3.5*ATR(20,D1)` hard stops, no target, and XAU/XAG spread ceilings
  of 1,500/500 points;
- both news axes and Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest validation, and static Q01 validation before Q02 handoff.

No magnitude threshold or ordering, fitted center or hedge ratio,
standardization, current-week price, oscillator, calendar/trend/volatility
filter, retry, external data, parameter sweep, target, trail, scale-in, grid,
martingale, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical XAU/XAG D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if exact-path tester count and host CPU are below governed ceilings. It
does not authorize a manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong week or endpoint
state, invalid session counts, strict-sign defect, wrong contrarian side,
repeated attempt, invalid risk mode, one-leg survivor, missing stop, wrong
next-week lifecycle, or nondeterminism. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, neutrality claims, and correlation
waivers.
