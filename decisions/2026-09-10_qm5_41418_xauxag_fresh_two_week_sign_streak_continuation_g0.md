# G0 Decision - QM5_41418 XAU/XAG Fresh Two-Week Sign-Streak Continuation

Date: 2026-09-10

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission on the
`agents/board-advisor` branch, bounded by
`decisions/2026-09-10_xauxag_fresh_two_week_sign_streak_continuation_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41418_xauxag-wstreak2-cont_card.md`.

## Identity

- EA ID: `QM5_41418`, allocated by `farmctl reserve-ea-ids`
- slug: `xauxag-wstreak2-cont`
- strategy ID: `MOP-CME-XAUXAG-WSTREAK2-CONT-20260910_S01`
- host/companion: `XAUUSD.DWX` / `XAGUSD.DWX`, D1, slots 0/1
- logical symbol: `QM5_41418_XAU_XAG_WSTREAK2_CONT_D1`
- mechanic: follow the first completion of two strict same-sign weekly
  gold-minus-silver returns after one strict opposite predecessor, for one week

## Gate Findings

- R1 `PASS_WITH_SHORT_HORIZON_RELATIVE_TRANSLATION_RISK`: the record preserves
  named peer-reviewed momentum and official exchange carrier evidence while
  stating that the exact weekly relative continuation is untested.
- R2 `PASS`: exact week anchors, synchronized endpoints, chronological signs,
  fresh-state condition, continuation sides, attempt, aggregate risk, hard
  stops, spreads, and lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU/XAG
  D1 data provides the runtime inputs; Q02 owns history/fill sufficiency.
- R4 `PASS`: deterministic native arithmetic only; no ML, banned signal,
  external runtime feed, adaptive fit, grid, martingale, or pyramid.

## Dedup Decision

The corrected canonical scan covered 4,898 registry rows, 1,508 repository
cards, and 45 current Strategy Wiki nodes. It found no exact or fuzzy identity.
Manual review separates the candidate from the opposite-side `QM5_41417`, the
three-week fade `QM5_41078`, and the overlapping-majority continuation
`QM5_41414`. Verdict:
`DISTINCT_XAUXAG_FRESH_TWO_WEEK_SIGN_STREAK_CONTINUATION`.

## Authorization Boundary

Approved for one branch-only build, strict Q01 validation, fixed-risk backtest
presets, and one paced logical Q02 enqueue if the CPU ceiling permits. Not
approved for a manual backtest, live/demo/shadow/stress preset, optimization,
AutoTrading, `T_Live`, deploy/live manifest, portfolio-gate mutation, portfolio
admission, correlation waiver, or decorrelation/neutrality claim.
