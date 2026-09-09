# WTI Winter Two-Week Agreement Momentum — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-winter-w2agree`
- Strategy ID: `BURAKOV-MOP-WTI-WINTER-W2AGREE-20260909_S01`
- Source packet:
  `strategy-seeds/sources/BURAKOV-MOP-WTI-WINTER-W2AGREE-20260909/source.md`
- Dedup receipt:
  `artifacts/qm5_wti_winter_w2agree_preallocation_dedup_20260909.json`

## Authority And Source Quality

The current OWNER PACER directive authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The source packet
joins the fully reviewed peer-reviewed WTI November-May record of Burakov,
Freidin, and Solovyev with the fully reviewed peer-reviewed
Moskowitz-Ooi-Pedersen time-series-momentum record. The exact weekly seasonal
interaction is an explicitly untested QM translation; no efficacy or
diversification claim transfers.

## Locked Mechanic

Trade preset-bound `XTIUSD.DWX` on D1. At the first tradable bar of each
Monday-anchored week from November through May, require the two immediately
completed adjacent three-to-five-session weeks to have the same strict
open-to-close log-return sign, then trade in that common direction for one
normalized week. Consume the attempt before fallible gates. Use fixed risk, a
frozen `3.5*ATR(20,D1)` hard stop, no target, and no retry.

No oscillator, moving average, volatility/volume/range rank, magnitude
threshold, external runtime feed, learned component, target, trail, scale-in,
pyramid, grid, or martingale is permitted.

## Duplicate Decision

The canonical checker covered 4,884 registry rows and 1,495 repository cards.
The configured Strategy Wiki root was unavailable and is not claimed as
checked. It returned five expected fuzzy family matches. Manual inspection
separates the exact-opposite WTI fade (`QM5_41403`), natural-gas seasonal
two-week siblings (`QM5_41401`, `QM5_41402`, `QM5_41395`, `QM5_41396`), the
year-round WTI one-week sign carrier (`QM5_41375`), and the prior-week
split-segment continuation (`QM5_41022`).

The WTI carrier, fixed November-May anchor regime, two adjacent complete-week
information objects, strict agreement, continuation direction, and next-week
lifecycle are jointly load-bearing. Verdict:
`DISTINCT_WTI_WINTER_TWO_WEEK_AGREEMENT_AFTER_MANUAL_REVIEW`.

## Authorization Boundary

This approval permits the approved card/G0 record, deterministic identity and
magic allocation, bounded V5 build, mandatory PACER input-pin audit before
compile enqueue, strict Q01, one fixed-risk preset, and one paced Q02 enqueue
below the CPU ceiling. It excludes manual backtests, optimization, portfolio
admission, correlation waivers, portfolio-gate edits, deployment, live
manifests, `T_Live`, AutoTrading, terminal control, and live use.

