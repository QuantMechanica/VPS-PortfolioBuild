# QM5_41403 WTI Winter Two-Week Exhaustion Fade — G0 Decision

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Card:
  `strategy-seeds/cards/approved/QM5_41403_wti-winter-w2fade_card.md`
- Source approval:
  `decisions/2026-09-09_wti_winter_two_week_fade_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 `PASS_WITH_HORIZON_AND_INTERACTION_TRANSLATION_RISK`: complete governed
  peer-reviewed WTI seasonality and academic commodity-reversal lineages; the
  exact weekly winter interaction is untested.
- R2 `PASS`: exact November-May anchors, normalized weekly clock, two
  completed-week packages, strict same-sign exhaustion, inverse direction,
  attempt, fixed risk, stop, spread, and rollover are fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic only; no trained component,
  banned signal indicator, external runtime feed, grid, martingale, or
  scale-in.

## Duplicate And Economic Boundary

The pre-allocation checker returned only expected XNG weekly fuzzy relatives;
the Wiki root was unavailable. Manual review separates the WTI 252-D1
long-only counterfade, exact one-month winter reversal, and year-round
split-segment weekly continuation. The candidate is a new joint state: WTI,
seven fixed winter months, two adjacent complete same-sign weeks, symmetric
contrarian direction, and a one-week lifecycle. Q02 retires below five
completed trades in any full scored year or on nonpositive governed economics;
no parameter rescue is authorized. Q09 alone may establish decorrelation.

## Authorization Boundary

Approval covers deterministic identity/magic allocation, V5 branch build,
mandatory PACER input-pin audit before compile enqueue, strict Q01, one
fixed-risk preset, and one paced Q02 enqueue only below the CPU ceiling. It
excludes manual backtests, portfolio admission, correlation waivers,
portfolio-gate edits, deployment, live manifests, `T_Live`, AutoTrading, and
live use.

