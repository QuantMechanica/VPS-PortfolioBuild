# G0 Decision — QM5_41366 XTI/XNG Weekly Decoupling Continuation

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41366_xtixng-decouple-cont`
- Strategy ID: `AI-CODEX-XTIXNG-DECOUPLE-CONT-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41366_xtixng-decouple-cont_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_weekly_decoupling_continuation_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_WEEKLY_CROSS_SECTIONAL_TRANSLATION_RISK`: complete peer-
  reviewed futures-continuation evidence plus complete government and peer-
  reviewed oil/gas evidence; the weekly opposite-sign pair is an explicitly
  untested QM synthesis.
- R2 `PASS`: synchronized consecutive completed weeks, three-to-five-session
  bounds, individual returns, strict opposite signs, winner-long/loser-short
  sides, weekly attempt, aggregate risk, hard stops, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data supplies every required runtime input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  banned indicator, external runtime feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical scan covered 4,846 registry rows and 1,459 repository cards. It
returned the expected fuzzy siblings `QM5_41365` and `QM5_41362`; the external
Strategy Wiki root was unavailable and remains an explicit coverage limit.

Manual review finds a distinct identity. `QM5_41365` uses the same weekly
opposite-sign state but reverses both legs, so every admitted package has the
opposite sides. `QM5_41362` uses two adjacent same-sign ratio returns and a
deceleration test. `QM5_12733` uses a monthly 126-D1 rank with a configurable
band. `QM5_41340` trades only WTI from a twelve-month direction. `QM5_12567`
is a single-symbol two-day XNG oscillator pullback.

Verdict:
`DISTINCT_WEEKLY_OPPOSITE_SIGN_XTI_XNG_WINNER_LONG_LOSER_SHORT_CONTINUATION`.

## Authorization Boundary

`g0_status: APPROVED` authorizes deterministic registry and magic allocation,
reference fixtures, one branch-only non-live V5 build, strict Q01, and one
paced logical-basket Q02 enqueue only if both five-sample CPU average and
maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
