# G0 Decision - QM5_41062 XAU/XAG Opposed Weekend-Gap Fade

Date: 2026-08-20

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-20_xauxag_opposed_weekend_gap_fade_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41062_xauxag-wgap-fade_card.md`.

## Identity

- EA ID: `QM5_41062`, allocated deterministically at commit `be7c379c2`
- slug: `xauxag-wgap-fade`
- strategy ID: `BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01`
- source approval commit: `fec22cf8d`
- magic allocation commit: `d975b6203`
- host: exact `XAUUSD.DWX`, D1, slot 0, magic `410620000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410620001`
- logical symbol: `QM5_41062_XAU_XAG_WGAPFADE_D1`
- mechanic: strict synchronized prior-Friday-close/current-Monday-open
  component-gap opposition, faded in both legs for one D1 session

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named peer-reviewed precious-
  metals calendar and gold/silver relationship lineages support the clock and
  carrier, with weak/adverse Monday evidence and the untested fade conjunction
  disclosed.
- R2 `PASS`: synchronized endpoints, current opens, strict component
  opposition, two-sided direction, durable attempt, aggregate fixed risk,
  equal notional, hard stops, spread caps, atomic repair, and next-D1 lifecycle
  are mechanical and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 histories plus active slots zero and one supply every runtime input.
  Q02 owns history alignment, fill, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamp, OHLC, logarithm, ATR risk plumbing,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.
- Card schema and ML-ban lint: `PASS` via
  `framework/scripts/skill_card_schema_lint.py` on the exact approved path.

## Duplicate Review

Before allocation, the canonical checker scanned 4,549 registry rows and 625
root cards and returned `CLEAN`. Manual review separates:

- fixed-direction pre-weekend `QM5_20019` and unconditional Monday
  `QM5_20095` packages;
- rolling ratio, residual, robust-score, and empirical-tail systems
  `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`;
- five-session run exhaustion `QM5_20275`;
- weekly/monthly flow decompositions `QM5_41030`, `QM5_41039`, `QM5_41040`,
  and `QM5_41057`; and
- the unrelated single-symbol cumulative-RSI commodity system `QM5_12567`.

None observes exactly one synchronized Friday-to-Monday event, requires the
individual metal gaps to oppose, fades either ratio direction, and exits at
the next D1 boundary. Verdict:
`CLEAN_XAUXAG_OPPOSED_WEEKEND_GAP_ONE_SESSION_FADE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU D1 host and XAG D1 companion on registered slots zero and one;
- synchronized current Monday and prior Friday timestamps separated by the
  exact calendar weekend, with a 180-minute entry grace;
- current opens and prior closes only, finite non-zero log gaps, strict sign
  opposition, and the exact two-sided contrarian mapping;
- one persistent broker-Monday attempt recorded before fallible execution
  gates;
- one logical equal-notional package within 20 percent rounding mismatch,
  with combined normalized stop risk capped at `RISK_FIXED=1000`;
- frozen `3.0*ATR(20,D1)` hard stops, no targets, and XAU/XAG spread ceilings
  of 1,500/500 points;
- atomic partial-package repair, first synchronized later-D1 close, four-day
  stale repair, both news axes OFF, and emergency Friday close ON at broker
  hour 21; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest, and static Q01 validation before any Q02 handoff.

No same-sign fallback, gap magnitude threshold, fitted center or beta, rolling
window, trend/season filter, direction flip, retry, external data, parameter
sweep, target, trailing stop, scale-in, grid, martingale, or after-result
rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical XAU/XAG D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if exact-path tester count and host CPU are below governed ceilings. It
does not authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong endpoints, any
current-bar leakage beyond its open, same-sign/zero-gap entry, wrong fade
side, repeated attempt, invalid risk or notional state, orphan survival,
missing stops, wrong next-D1 lifecycle, or nondeterminism. Q09 alone may
establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
