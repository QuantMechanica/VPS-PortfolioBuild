# G0 Decision — QM5_41367 XTI/XNG Weekly Common-Shock Continuation

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41367_xtixng-commonshock-cont`
- Strategy ID: `AI-CODEX-XTIXNG-COMMONSHOCK-CONT-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41367_xtixng-commonshock-cont_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_weekly_common_shock_continuation_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_WEEKLY_TWO_ASSET_TRANSLATION_RISK`: complete peer-reviewed
  commodity cross-sectional-momentum evidence plus complete government and
  peer-reviewed oil/gas evidence; the weekly two-asset common-sign package is
  an explicitly untested QM synthesis.
- R2 `PASS`: synchronized consecutive completed weeks, three-to-five-session
  bounds, individual returns, strict same signs, strict relative rank,
  winner-long/loser-short sides, weekly attempt, aggregate risk, hard stops,
  and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data supplies every required runtime input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  banned indicator, external runtime feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical scan covered 4,847 registry rows and 1,460 repository cards. It
found no exact identity and returned six expected fuzzy family matches; the
external Strategy Wiki root was unavailable and remains an explicit coverage
limit.

Manual review finds a distinct identity. `QM5_41361` uses the identical
same-sign weekly state but reverses both legs. `QM5_41366` follows the winner
only in the disjoint opposite-sign state. `QM5_41362` uses two adjacent ratio
returns and a deceleration condition. `QM5_12733` uses a monthly 126-D1 rank
with a configurable band. `QM5_41086` uses a different XAU/XAG carrier.

Verdict:
`DISTINCT_WEEKLY_SAME_SIGN_XTI_XNG_WINNER_LONG_LOSER_SHORT_CONTINUATION`.

## Authorization Boundary

`g0_status: APPROVED` authorizes deterministic registry and magic allocation,
reference fixtures, one branch-only non-live V5 build, strict Q01, and one
paced logical-basket Q02 enqueue only if both the fresh five-sample CPU average
and maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
