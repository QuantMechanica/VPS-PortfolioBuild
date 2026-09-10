# QM5_41412 WTI Weekly Alternation Fade — G0 Decision

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41412_wti-walt3-fade_card.md`
- Source approval:
  `decisions/2026-09-10_wti_weekly_alternation_fade_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 `PASS_WITH_HORIZON_AND_STATE_TRANSLATION_RISK`: academic commodity-
  reversal lineage and complete peer-reviewed weekly WTI lineage are retained;
  the exact standalone alternating-state fade is untested.
- R2 `PASS`: clock, weekly packages, strict signs, reversal direction,
  attempt, fixed risk, stop, spread, and hold are fixed.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic only; no trained component,
  banned signal indicator, external runtime feed, grid, martingale, or
  scale-in.

## Duplicate And Economic Boundary

No exact identity exists. `QM5_41411` is the expected fuzzy sibling but
follows, rather than fades, the newest sign. Two-week transitions, seasonal
same-sign fades, unconditional one-week reversals, and OHLC-geometry systems
use different states. Q02 retires below five completed trades in any full
scored year or on nonpositive governed economics. Q09 alone may establish
decorrelation.

## Authorization Boundary

Approval covers deterministic identity/magic allocation, V5 branch build,
mandatory PACER input-pin audit before compile enqueue, strict Q01, one
fixed-risk preset, and one paced Q02 enqueue only below the CPU ceiling. It
excludes manual backtests, portfolio admission, correlation waivers,
portfolio-gate edits, deployment, live manifests, `T_Live`, AutoTrading, and
live use.
