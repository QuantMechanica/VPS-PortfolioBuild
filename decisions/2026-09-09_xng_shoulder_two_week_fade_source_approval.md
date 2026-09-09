# XNG Shoulder Two-Week Exhaustion Fade — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `xng-shoulder-w2fade`
- Strategy ID: `EIA-MOP-XNG-SHOULDER-W2FADE-20260909_S01`
- Source packet:
  `strategy-seeds/sources/EIA-MOP-XNG-SHOULDER-W2FADE-20260909/source.md`
- Dedup receipt:
  `artifacts/qm5_xng_shoulder_w2fade_preallocation_dedup_20260909.json`

## Authority And Locked Mechanic

The current OWNER pacer instruction authorizes one structural commodity/energy
card and build. The source packet preserves the completely read official EIA
shoulder-season context and peer-reviewed MOP commodity persistence lineage.

The immutable candidate trades preset-bound `XNGUSD.DWX` on D1. On the first
tradable bar of each Monday-anchored April, May, September, or October week, it
reads the two immediately completed adjacent three-to-five-session weeks. Two
positive open-to-close log returns trigger a short; two negative returns
trigger a long. Disagreement and exact zero are flat. The week is consumed
before fallible gates; the position closes next week. Backtest risk is fixed at
1000 with percent risk zero, a frozen `3.5*ATR(20,D1)` stop, no target, and a
1,500-point spread ceiling.

No oscillator, moving average, volatility rank, magnitude threshold, external
runtime feed, trained component, target, trail, scale-in, pyramid, grid,
martingale, or retry is permitted.

## Reputable-Source And Duplicate Decision

- R1 passes with disclosed cross-source, horizon, fade, and CFD translation
  risk; no efficacy transfers.
- R2 passes because the clock, packages, sign agreement, inverse side,
  lifecycle, and risk controls are mechanical.
- R3 passes on registered native `XNGUSD.DWX` D1 history.
- R4 passes because the runtime is deterministic and non-ML.

The canonical checker scanned 4,881 registry rows and 1,492 cards, returned no
exact identity, and raised `QM5_41392` and `QM5_41396` as expected fuzzy
neighbors. The configured Strategy Wiki root was unavailable. Manual review
separates the two-week shoulder fade from 41392's unconditional one-week fade,
41396's summer continuation, and 12567's RSI pullback. Verdict:
`DISTINCT_XNG_SHOULDER_TWO_ADJACENT_WEEK_EXHAUSTION_FADE_AFTER_FAMILY_REVIEW`.

## Authorization Boundary

Approval permits the card/G0 record, deterministic ID and magic allocation,
bounded V5 build, mandatory PACER input-pin audit before compile enqueue,
strict Q01, and one paced Q02 enqueue below the CPU ceiling. It excludes manual
backtests, optimization, portfolio admission or gate edits, correlation
waivers, deployment, live manifests, `T_Live`, AutoTrading, and live use.
