# G0 Decision - QM5_41081 XNG Completed-Week Close-Location Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-21_xng_completed_week_close_location_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41081_xng-wclose-location-mom_card.md`.

## Identity

- EA ID: `QM5_41081`, allocated deterministically at commit `fe2015ce2`
- slug: `xng-wclose-location-mom`
- strategy ID: `MOP-XNG-WCLOSE-LOCATION-MOM-2026_S01`
- source approval commit: `2f2604d49`
- magic allocation and resolver commit: `b76ba3d42`
- active host: exact `XNGUSD.DWX`, D1, slot 0, magic `410810000`
- mechanic: follow the immediately completed broker week's strict parent-
  close-to-new-close return sign only when the new close finishes strictly
  above `0.80` or below `0.20` of that week's own high-low range

The governed allocation order created the EA directory before the active
slot-zero magic row. Resolver regeneration retained 17,561 active rows with
zero drops and preserved the new row.

## Gate Findings

- R1 `PASS_WITH_WEEKLY_CLOSE_LOCATION_TRANSLATION_RISK`: one bounded child
  source carries named-author peer-reviewed JFE/DOI lineage and complete-read
  evidence. The weekly close-location confirmation is an untested QM
  hypothesis and is disclosed as such.
- R2 `PASS`: exact first-week-bar clock, label convention, two consecutive
  completed weekly packages, three-to-five session bounds, OHLC aggregation,
  endpoint return, strict close-location boundaries, direction, durable
  attempt, risk, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native XNG D1
  supplies every runtime input. Q02 owns history, density, costs, label, and
  continuous-CFD basis falsification.
- R4 `PASS`: deterministic timestamp, completed OHLC, logarithm, comparison,
  ATR, quote, position, deal, and terminal-state arithmetic only; no banned
  signal, external runtime feed, adaptive fit, grid, martingale, scale-in, or
  pyramid.
- Card schema and prohibited-signal lint must pass on the approved card path
  before implementation.

## Duplicate Review

The canonical checker included author and mechanic fields, scanned 4,568
registry rows and 625 root cards, and returned `CLEAN`, with no exact or fuzzy
match. Manual review separates certified `QM5_12567`'s long-only two-day
oscillator pullback, monthly XNG return-sign systems, adjacent-week sign-flip
systems, rolling volatility/volume-ranked weekly momentum, and current-week
range breakouts. `QM5_41080` is the WTI carrier sibling and transfers no
result.

This card alone combines exact XNG, two consecutive completed Monday-anchored
packages, the newest weekly high-low range, strict parent-close-to-new-close
sign, strict own-range `0.80` / `0.20` settlement confirmation, consumed
weekly attempt, and full-next-week hold. Verdict:
`CLEAN_XNG_COMPLETED_WEEK_RETURN_SIGN_WITH_OWN_RANGE_CLOSE_LOCATION_CONFIRMATION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XNG D1 host slot 0 under magic `410810000`;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- one uniform native or exact `+1`-day energy-label convention;
- two consecutive completed weekly packages, each containing three to five
  strictly ordered D1 sessions;
- newest package `H0`, `L0`, `C0`, parent final close `C1`, strict
  `r=ln(C0/C1)`, and strict `clv=(C0-L0)/(H0-L0)`;
- BUY only on `r>0 && clv>0.80`, SELL only on `r<0 && clv<0.20`, equality
  and every disagreement flat;
- one persistent Monday-anchor attempt recorded before fallible gates;
- one `RISK_FIXED=1000` budget, frozen `3.5*ATR(20,D1)` hard stop, no target,
  and 1,500-point spread ceiling;
- both news axes and Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before Q02 handoff.

No threshold sweep, parent-range breakout, return-magnitude gate, current-week
price, oscillator, calendar/volume/volatility/moving-average/inventory filter,
retry, external data, target, trail, scale-in, grid, martingale, or after-
result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one XNG D1 `RISK_FIXED`
backtest set, strict Q01, and one paced target-only Q02 enqueue only if exact-
path tester count and host CPU are below governed ceilings. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero positions, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, wrong label/week/
session state, invalid OHLC or endpoint ordering, equality accepted at a
strict boundary, wrong side, repeated attempt, invalid risk mode, missing
stop, wrong next-week lifecycle, or nondeterminism. Q09 alone may establish
realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.

