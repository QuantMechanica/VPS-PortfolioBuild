# G0 Decision - QM5_41423 WTI Fresh Two-Week Sign-Streak Reversion

Date: 2026-09-10

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission on the
`agents/board-advisor` branch, bounded by
`decisions/2026-09-10_wti_fresh_two_week_sign_streak_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41423_wti-wstreak2-fade_card.md`.

## Identity

- EA ID: `QM5_41423`, allocated by `farmctl reserve-ea-ids`
- slug: `wti-wstreak2-fade`
- strategy ID: `YANG-WTI-WSTREAK2-FADE-20260910_S01`
- carrier: `XTIUSD.DWX`, D1, slot 0, magic `414230000`
- mechanic: fade the first completion of two strict same-sign completed-week
  WTI returns after one strict opposite predecessor, for one week

## Gate Findings

- R1 `PASS_WITH_SHORT_HORIZON_REVERSAL_TRANSLATION_RISK`: academic commodity
  reversal lineage plus named peer-reviewed momentum research, complete-read
  evidence, DOI, and explicit WTI membership; the exact weekly state is
  untested.
- R2 `PASS`: week anchors, endpoints, signs, fresh-state condition, opposite
  side, attempt, risk, stop, spread, and lifecycle are fixed.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  XTIUSD.DWX D1 data supplies runtime inputs; Q02 owns history/fill sufficiency.
- R4 `PASS`: deterministic native arithmetic only; no ML, banned signal,
  external runtime feed, grid, martingale, or pyramid.

## Dedup Decision

The canonical scan covered 4,903 registry rows, 1,513 repository cards, and 45
Strategy Wiki nodes and found no exact identity. Manual review separates the
three-week fade's additional endpoint and disjoint event state, the
directionally opposite two-week continuation sibling, and seasonal two-week
systems. Verdict: `DISTINCT_WTI_FRESH_TWO_WEEK_SIGN_STREAK_REVERSION`.

## Authorization Boundary

Approved for one branch-only build, strict Q01 validation, one fixed-risk D1
backtest preset, and one paced Q02 enqueue if CPU permits. Not approved for a
manual backtest, live/demo/shadow/stress preset, optimization, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate mutation, portfolio admission,
correlation waiver, or decorrelation claim.
