# G0 Decision — QM5_41369 XTI/XNG Common-Shock Leader-Persistence Continuation

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41369_xtixng-cs-leadpersist-cont`
- Strategy ID: `AI-CODEX-XTIXNG-CS-LEADPERSIST-CONT-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41369_xtixng-cs-leadpersist-cont_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_common_shock_leader_persistence_continuation_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_TWO_WEEK_LEADER_PERSISTENCE_TRANSLATION_RISK`: complete
  peer-reviewed commodity relative-return evidence plus complete government
  and peer-reviewed oil/gas evidence; the two-week common-shock same-leader
  continuation is an explicitly untested QM synthesis.
- R2 `PASS`: three synchronized completed-week endpoints, three-to-five-
  session bounds, two strict same-sign states, strict relative-leader
  persistence, newest-winner follow, weekly attempt, aggregate risk, hard
  stops, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data supplies every required runtime input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  banned indicator, external runtime feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical scan covered 4,849 registry rows and 1,462 repository cards. It
found no exact identity and returned five expected fuzzy family matches; the
external Strategy Wiki root was unavailable and remains an explicit coverage
limit.

Manual review finds a distinct identity. `QM5_41367` follows one common-sign
week, while this rule requires two and the same strict leader in both.
`QM5_41368` requires a leader switch and fades the newest winner. `QM5_41361`
fades a one-week winner. `QM5_41365` and `QM5_41366` use disjoint opposite-sign
states. `QM5_41362` classifies relative-return deceleration, while this rule
ignores magnitude and requires shared individual-leg direction in both weeks.

Verdict:
`DISTINCT_TWO_WEEK_COMMON_SHOCK_STRICT_SAME_LEADER_PERSISTENCE_CONTINUATION`.

## Authorization Boundary

`g0_status: APPROVED` authorizes deterministic registry and magic allocation,
reference fixtures, one branch-only non-live V5 build, strict Q01, and one
paced logical-basket Q02 enqueue only if both the fresh five-sample CPU average
and maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
