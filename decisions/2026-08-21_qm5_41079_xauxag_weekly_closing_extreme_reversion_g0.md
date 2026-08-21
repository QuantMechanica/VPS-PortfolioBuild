# G0 Decision - QM5_41079 XAU/XAG Weekly Closing-Extreme Reversion

Date: 2026-08-21

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-21_xauxag_weekly_closing_extreme_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41079_xauxag-wclose-extreme-rv_card.md`.

## Identity

- EA ID: `QM5_41079`, allocated deterministically at commit `4a7c2d633`
- slug: `xauxag-wclose-extreme-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026_S01`
- source approval commit: `37d65f4e0`
- intended host: exact `XAUUSD.DWX`, D1, slot 0, magic `410790000`
- intended companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410790001`
- logical symbol: `QM5_41079_XAU_XAG_WCLOSE_EXTREME_RV_D1`
- mechanic: fade the final synchronized ratio close of the immediately
  completed broker week when it is strictly above or below every earlier
  synchronized ratio close in that same week

Build remains gated until the governed allocator creates active slot-zero and
slot-one magic rows and the regenerated resolver retains both rows.

## Gate Findings

- R1 `PASS_WITH_WEEKLY_CLOSING_EXTREME_TRANSLATION_RISK`: one bounded child
  source carries a named-author peer-reviewed DOI record plus official
  exchange carrier evidence. The within-week closing-rank fade is an untested
  QM condition and is disclosed as such.
- R2 `PASS`: exact first-week-bar clock, prior-week membership, synchronized
  three-to-five-session close set, chronological ratios, strict newest rank,
  contrarian side, durable attempt, aggregate risk, equal-notional target,
  hard stops, spreads, and lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 routes supply every runtime input. Q02 owns paired history, fills,
  costs, density, and continuous-CFD basis falsification.
- R4 `PASS`: deterministic timestamp, price, logarithm, comparison, ATR,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema and prohibited-signal lint must pass on the approved card path
  before implementation.

## Duplicate Review

The canonical pre-allocation checker scanned 4,566 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates rolling ratio/residual systems, daily sign-run exhaustion, daily
failed-channel breaks, monthly cross-sectional rank systems, weekly/monthly
flow decomposition, opposed weekend gaps, weekly NR7 breakout, and every
completed-week sign/magnitude variant through `QM5_41078`.

This card alone requires every synchronized D1 close pair in the immediately
completed Monday-anchored week, a bounded three-to-five-session set, and a
strict newest upper/lower ratio rank before a contrarian one-week package.
Verdict:
`CLEAN_XAUXAG_COMPLETED_WEEK_CLOSING_EXTREME_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card after active magic allocation
with:

- exact XAU D1 host slot 0 and XAG D1 companion slot 1 under governed magics
  and one logical basket manifest;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- every synchronized positive D1 close pair from the immediately preceding
  Monday-anchored broker week, exactly three to five unique sessions, ordered
  oldest to newest;
- strict newest upper/lower gold-minus-silver log-ratio rank and contrarian
  package side;
- one persistent Monday-anchor attempt recorded before fallible gates;
- one aggregate `RISK_FIXED=1000` budget, equal absolute notional target,
  frozen `3.5*ATR(20,D1)` hard stops, no target, and XAU/XAG spread ceilings
  of 1,500/500 points;
- both news axes and Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest validation, and static Q01 validation before Q02 handoff.

No distance threshold, fitted center or hedge ratio, standardization, current-
week price, oscillator, calendar/trend/volatility filter, retry, external data,
parameter sweep, target, trail, scale-in, grid, martingale, or after-result
rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical XAU/XAG D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if exact-path tester count and host CPU are below governed ceilings. It
does not authorize a manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong week/session state,
invalid ordering or synchronization, non-strict or interior newest rank, wrong
contrarian side, repeated attempt, invalid risk mode, one-leg survivor,
missing stop, wrong next-week lifecycle, or nondeterminism. Q09 alone may
establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, neutrality claims, and correlation
waivers.
