# G0 Decision - QM5_41075 XAU/XAG Weekly Reversal-Overshoot Reversion

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_xauxag_weekly_reversal_overshoot_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41075_xauxag-wovershoot-rv_card.md`.

## Identity

- EA ID: `QM5_41075`, allocated deterministically at commit `ecc559ee0`
- slug: `xauxag-wovershoot-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WOVERSHOOT-RV-2026_S01`
- source approval commit: `9f30c75c8`
- host: exact `XAUUSD.DWX`, D1, slot 0, expected formula magic `410750000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, expected formula magic `410750001`
- logical symbol: `QM5_41075_XAU_XAG_WOVERSHOOT_RV_D1`
- mechanic: strict sign opposition and strict newest absolute dominance
  between two adjacent completed weekly gold-minus-silver returns, with the
  newest relative reversal faded for one week

The build authorization becomes operative only after the governed allocator
has created active slot-zero and slot-one rows and regenerated the resolver
without dropping either row.

## Gate Findings

- R1 `PASS_WITH_WEEKLY_OVERSHOOT_TRANSLATION_RISK`: one bounded child source
  carries a named-author peer-reviewed DOI record plus official exchange
  carrier evidence. The weekly reversal-overshoot fade is an untested QM
  condition and is disclosed as such.
- R2 `PASS`: exact first-week-bar clock, synchronized endpoints, chronological
  relative returns, strict state, side, durable attempt, aggregate risk,
  equal-notional target, hard stops, spreads, and lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 routes supply every runtime input. Q02 owns paired history, fills,
  costs, density, and continuous-CFD basis falsification.
- R4 `PASS`: deterministic timestamp, price, logarithm, comparison, ATR,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema and prohibited-signal lint must pass on the approved card path
  before implementation.

## Duplicate Review

The canonical pre-allocation checker scanned 4,562 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separates rolling ratio/residual systems, daily five-return exhaustion,
monthly cross-sectional rank systems, weekly/monthly flow decomposition,
opposed weekend gaps, weekly NR7 breakout, and `QM5_41066` same-sign
deceleration.

This card alone requires exactly two adjacent non-overlapping completed
broker-week relative returns to have strict opposite signs while the newest
absolute move is strictly larger, then fades only that newest return for the
next broker week. Its state is mutually exclusive with `QM5_41066`. Verdict:
`CLEAN_XAUXAG_OPPOSITE_WEEK_REVERSAL_OVERSHOOT_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card after active magic allocation
with:

- exact XAU D1 host slot 0 and XAG D1 companion slot 1 under the governed
  magics and one logical basket manifest;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- three consecutive completed synchronized Monday-anchored week-end pairs,
  two adjacent gold-minus-silver log returns, strict sign opposition, strict
  newest absolute dominance, and inverse-newest-return package direction;
- one persistent Monday-anchor attempt recorded before fallible execution
  gates;
- one aggregate `RISK_FIXED=1000` budget, equal absolute notional target,
  frozen `3.5*ATR(20,D1)` hard stops, no target, and XAU/XAG spread ceilings
  of 1,500/500 points;
- both news axes and Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest validation, and static Q01 validation before Q02 handoff.

No threshold, fitted center or hedge ratio, standardization, same-sign entry,
equality entry, current-week price, overlapping return interval, oscillator,
calendar/trend/volatility filter, retry, external data, parameter sweep,
target, trail, scale-in, grid, martingale, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical XAU/XAG D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if exact-path tester count and host CPU are below governed ceilings. It
does not authorize a manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong week or endpoint
state, sign/dominance defect, wrong inverse side, repeated attempt, invalid
risk mode, one-leg survivor, missing stop, wrong next-week lifecycle, or
nondeterminism. Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, neutrality claims, and correlation
waivers.

