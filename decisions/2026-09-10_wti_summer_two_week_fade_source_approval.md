# WTI Summer Two-Week Exhaustion Fade — Source Approval

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-summer-w2fade`
- Strategy ID: `BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910_S01`
- Source packet:
  `strategy-seeds/sources/BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910/source.md`
- Dedup receipt:
  `artifacts/qm5_wti_summer_w2fade_preallocation_dedup_20260910.json`

## Authority And Source Quality

The current OWNER PACER directive authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The source packet
joins the fully reviewed peer-reviewed WTI May-October record of Burakov,
Freidin, and Solovyev with the fully reviewed academic
Yang-Goncu-Pantelous commodity-reversal record. The exact weekly seasonal
interaction is an explicitly untested QM translation; no efficacy or
diversification claim transfers.

## Locked Mechanic

Trade preset-bound `XTIUSD.DWX` on D1. At the first tradable bar of each
Monday-anchored week from June through October, require the two immediately
completed adjacent three-to-five-session weeks to have the same strict
open-to-close log-return sign, then trade the opposite direction for one
normalized week. Consume the attempt before fallible gates. Use fixed risk, a
frozen `3.5*ATR(20,D1)` hard stop, no target, and no retry.

No oscillator, moving average, volatility/volume/range rank, magnitude
threshold, external runtime feed, learned component, target, trail, scale-in,
pyramid, grid, or martingale is permitted.

## Duplicate Decision

The canonical checker covered 4,887 registry rows and 1,497 repository cards.
The configured Strategy Wiki root was unavailable and is not claimed as
checked. It returned four expected fuzzy family matches. Manual inspection
separates the same-regime WTI continuation (`QM5_41406`), the disjoint WTI
winter fade (`QM5_41403`), the XNG summer agreement (`QM5_41396`), and the XNG
shoulder fade (`QM5_41401`). Repository review also separates the year-round
WTI one-week sign carrier (`QM5_41375`) and prior-week split-segment
continuation (`QM5_41022`).

The WTI carrier, fixed June-October anchor regime, two adjacent complete-week
information objects, strict agreement, inverse direction, and next-week
lifecycle are jointly load-bearing. Verdict:
`DISTINCT_WTI_SUMMER_TWO_WEEK_EXHAUSTION_FADE_AFTER_MANUAL_REVIEW`.

## Authorization Boundary

This approval permits the approved card/G0 record, deterministic identity and
magic allocation, bounded V5 build, mandatory PACER input-pin audit before
compile enqueue, strict Q01, one fixed-risk preset, and one paced Q02 enqueue
below the CPU ceiling. It excludes manual backtests, optimization, portfolio
admission, correlation waivers, portfolio-gate edits, deployment, live
manifests, `T_Live`, AutoTrading, terminal control, and live use.


