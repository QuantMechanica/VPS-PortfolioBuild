# XNG Winter Two-Week Exhaustion Fade — Source Approval

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `xng-winter-w2fade`
- Strategy ID: `EIA-YANG-XNG-WINTER-W2FADE-20260910_S01`
- Source packet:
  `strategy-seeds/sources/EIA-YANG-XNG-WINTER-W2FADE-20260910/source.md`
- Dedup receipt:
  `artifacts/qm5_xng_winter_w2fade_preallocation_dedup_20260910.json`

## Authority And Source Quality

The current OWNER PACER directive authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The source packet
joins completely read governed records for official EIA natural-gas
seasonality and Yang-Goncu-Pantelous commodity reversal. The exact weekly
winter interaction is untested and no efficacy or diversification claim
transfers.

## Locked Mechanic

Trade preset-bound `XNGUSD.DWX` on D1. At the first tradable bar of each
Monday-anchored November-March week, require the two immediately completed
adjacent three-to-five-session weeks to have the same strict open-to-close
log-return sign, then trade the opposite direction for one normalized week.
Consume the attempt before fallible gates. Use fixed risk, a frozen
`3.5*ATR(20,D1)` hard stop, no target, no retry, and native zero-offset D1
labels.

No oscillator, moving average, magnitude threshold, external runtime feed,
learned component, target, trail, scale-in, pyramid, grid, or martingale is
permitted.

## Duplicate Decision

The canonical checker covered 4,888 registry rows and 1,498 repository cards.
The configured Strategy Wiki root was unavailable and is not claimed as
checked. It found no exact identity and returned expected fuzzy family
members. Manual review separates the same-carrier continuation (`QM5_41402`),
different-carrier WTI winter fade (`QM5_41403`), disjoint XNG shoulder fade
(`QM5_41401`), one-week winter continuation (`QM5_41395`), and certified
two-day RSI pullback (`QM5_12567`). Verdict:
`DISTINCT_XNG_WINTER_TWO_WEEK_EXHAUSTION_FADE_AFTER_MANUAL_REVIEW`.

## Authorization Boundary

Approval permits the approved card/G0 record, deterministic identity and magic
allocation, bounded V5 build, mandatory PACER input-pin audit before compile
enqueue, strict Q01, one fixed-risk preset, and one paced Q02 enqueue below the
CPU ceiling. It excludes manual backtests, optimization, portfolio admission,
correlation waivers, portfolio-gate edits, deployment, live manifests,
`T_Live`, AutoTrading, terminal control, and live use.

