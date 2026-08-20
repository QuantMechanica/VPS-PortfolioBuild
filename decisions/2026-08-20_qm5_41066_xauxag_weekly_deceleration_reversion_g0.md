# G0 Decision - QM5_41066 XAU/XAG Weekly Deceleration Reversion

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_xauxag_weekly_deceleration_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41066_xauxag-wdecay-rv_card.md`.

## Identity

- EA ID: `QM5_41066`, allocated deterministically at commit `2475a7269`
- slug: `xauxag-wdecay-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WDECAY-RV-2026_S01`
- source approval commit: `064e189bc`
- magic allocation commit: `9b61b28c1`
- host: exact `XAUUSD.DWX`, D1, slot 0, magic `410660000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410660001`
- logical symbol: `QM5_41066_XAU_XAG_WDECAY_RV_D1`
- mechanic: strict same-sign and strict magnitude deceleration between two
  adjacent completed weekly gold-minus-silver returns, faded for one week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_EXHAUSTION_TRANSLATION_RISK`: one bounded child source
  carries a named-author peer-reviewed DOI record plus official exchange
  carrier evidence. The weekly deceleration fade is an untested QM condition
  and is disclosed as such.
- R2 `PASS`: exact first-week-bar clock, synchronized endpoints, chronological
  relative returns, strict state, side, durable attempt, aggregate risk,
  equal-notional target, hard stops, spreads, and lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 routes and active slots supply every runtime input. Q02 owns paired
  history, fills, costs, density, and continuous-CFD basis falsification.
- R4 `PASS`: deterministic timestamp, price, logarithm, comparison, ATR,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema and prohibited-ML lint: `PASS` on the approved card path.

## Duplicate Review

The canonical pre-allocation checker scanned 4,553 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates the daily five-return run fade (`QM5_20275`), rolling ratio and
residual systems, weekly/monthly intraday-flow decompositions, opposed weekend
gap fade (`QM5_41062`), and weekly NR7 breakout (`QM5_41060`).

This card alone requires exactly two adjacent non-overlapping completed broker-
week relative returns to share a strict sign while the newest magnitude is
strictly smaller, then fades that direction for the next broker week. Verdict:
`CLEAN_XAUXAG_TWO_WEEK_SAME_SIGN_DECELERATION_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU D1 host slot 0 and XAG D1 companion slot 1 under the registered
  magics and one logical basket manifest;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- three consecutive completed synchronized Monday-anchored week-end pairs,
  two adjacent gold-minus-silver log returns, strict same sign, strict newest-
  magnitude decay, and inverse package direction;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one aggregate `RISK_FIXED=1000` budget, equal absolute notional target,
  frozen `3.5*ATR(20,D1)` hard stops, no target, and XAU/XAG spread ceilings
  of 1,500/500 points;
- both news axes and Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest validation, and static Q01 validation before Q02 handoff.

No threshold, fitted center or hedge ratio, standardization, acceleration,
opposed-sign entry, equality entry, current-week price, overlapping return
interval, oscillator, calendar/trend/volatility filter, retry, external data,
parameter sweep, target, trail, scale-in, grid, martingale, or after-result
rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical XAU/XAG D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if exact-path tester count and host CPU are below governed ceilings. It
does not authorize a manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong week or endpoint
state, sign/deceleration defect, wrong inverse side, repeated attempt, invalid
risk mode, one-leg survivor, missing stop, wrong next-week lifecycle, or
nondeterminism. Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, neutrality claims, and correlation
waivers.

