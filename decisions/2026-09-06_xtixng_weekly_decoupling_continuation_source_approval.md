# XTI/XNG Weekly Decoupling Continuation — Source Approval

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one market-neutral XTI/XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue below the
  hard CPU ceiling
- Proposed slug: `xtixng-decouple-cont`
- Strategy ID: `AI-CODEX-XTIXNG-DECOUPLE-CONT-20260906_S01`
- Source packet:
  `strategy-seeds/sources/AI-CODEX-XTIXNG-DECOUPLE-CONT-20260906/source.md`
- Dedup receipt:
  `artifacts/qm5_xtixng_decouple_cont_preallocation_dedup_20260906.json`

## Authority And Complete-Read Evidence

The current explicit OWNER mission authorizes one new reputable-source,
low-frequency commodity/energy edge and expressly permits a market-neutral
structural commodity construction. Before approval, the complete governed
`MOP-TSMOM-2012` and `VILLAR-RAMBERG-OILGAS-2026` packets were read. They
record end-to-end reads of a peer-reviewed JFE momentum paper, a U.S. EIA
report, and a peer-reviewed *Energy Journal* paper, including adverse evidence.

The sources support futures continuation and a weak, time-varying physical and
economic oil/gas carrier. They do not test strict opposite weekly returns or a
weekly winner-minus-loser Darwinex CFD package. The exact conjunction is a
bounded QM translation whose efficacy remains wholly unproven.

## R1-R4 Decision

- R1 `PASS_WITH_WEEKLY_CROSS_SECTIONAL_TRANSLATION_RISK`: complete reputable
  evidence with adverse instability retained and no transferred efficacy.
- R2 `PASS`: synchronized consecutive completed weeks, session bounds,
  individual returns, strict opposite signs, winner-long/loser-short sides,
  durable weekly attempt, aggregate risk, stops, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories supply every market input.
- R4 `PASS`: deterministic timestamps, logarithms, comparisons, ATR, quotes,
  positions, deals, and durable state only; no ML or banned indicator.

## Duplicate Decision

The canonical checker covered 4,846 registry rows and 1,459 repository cards.
It returned the expected fuzzy siblings `QM5_41365` (same weekly state but
opposite reversion sides) and `QM5_41362` (same-sign two-week ratio
deceleration). Manual review also separates monthly 126-day cross-sectional
momentum `QM5_12733`, WTI-only twelve-month divergence trend `QM5_41340`, and
single-symbol oscillator `QM5_12567`. The external Strategy Wiki root was
unavailable; that limitation remains explicit rather than relabeled as a
complete-universe pass.

Verdict:
`DISTINCT_WEEKLY_OPPOSITE_SIGN_XTI_XNG_WINNER_LONG_LOSER_SHORT_CONTINUATION`.

## Authorization Boundary

This approval permits the named card extraction and bounded build path. It
excludes manual backtests, optimization, portfolio-gate changes, portfolio
admission, correlation waivers, deployment, live manifests, `T_Live`,
AutoTrading, and live use. Q02 must retire the edge on zero packages, fewer
than five packages in any full post-warm-up year, or nonpositive economics.
