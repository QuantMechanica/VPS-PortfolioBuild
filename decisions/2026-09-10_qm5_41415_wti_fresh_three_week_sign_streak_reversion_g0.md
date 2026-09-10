# QM5_41415 WTI Fresh Three-Week Sign-Streak Reversion — G0 Decision

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41415_wti-wstreak3-fade_card.md`
- Source approval:
  `decisions/2026-09-10_wti_fresh_three_week_sign_streak_reversion_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 `PASS_WITH_WEEKLY_PATH_AND_REVERSAL_TRANSLATION_RISK`: academic commodity-
  reversal lineage and a complete peer-reviewed WTI record are retained; the
  exact fresh weekly streak fade is untested.
- R2 `PASS`: clock, endpoints, strict fresh-streak state, opposite direction,
  attempt, fixed risk, stop, spread, and hold are fixed.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic only; no trained component,
  banned signal, external runtime feed, grid, martingale, or scale-in.

## Duplicate And Economic Boundary

No exact identity exists. `QM5_41074` is the expected fuzzy sibling but follows,
rather than fades, the identical fresh-streak state. `QM5_41412` requires a
disjoint alternating state. Q02 retires below five completed trades in any
full scored year or on nonpositive governed economics. Q09 alone may establish
decorrelation.

## Authorization Boundary

Approval covers deterministic identity/magic allocation, V5 branch build,
mandatory PACER input-pin audit before compile enqueue, strict Q01, one
fixed-risk preset, and one paced Q02 enqueue only below the CPU ceiling. It
excludes manual backtests, portfolio admission, correlation waivers,
portfolio-gate edits, deployment, live manifests, `T_Live`, AutoTrading, and
live use.
