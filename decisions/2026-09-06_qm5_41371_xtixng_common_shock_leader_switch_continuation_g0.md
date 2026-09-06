# G0 Decision — QM5_41371 XTI/XNG Common-Shock Leader-Switch Continuation

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41371_xtixng-cs-leadswitch-cont`
- Strategy ID: `AI-CODEX-XTIXNG-CS-LEADSWITCH-CONT-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41371_xtixng-cs-leadswitch-cont_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_common_shock_leader_switch_continuation_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_TWO_WEEK_LEADER_SWITCH_CONTINUATION_TRANSLATION_RISK`:
  complete peer-reviewed commodity relative-return evidence plus complete
  government and peer-reviewed oil/gas evidence; the two-week common-shock
  leader-switch continuation is an explicitly untested QM synthesis.
- R2 `PASS`: three synchronized completed-week endpoints, three-to-five-
  session bounds, two strict same-sign states, strict relative-leader switch,
  newest-winner continuation, weekly attempt, aggregate risk, hard stops, and
  lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data supplies every required runtime input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  banned indicator, external runtime feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical scan covered 4,851 registry rows and 1,464 repository cards. It
found no exact identity and returned eight expected fuzzy family matches; the
external Strategy Wiki root was unavailable and remains an explicit coverage
limit.

Manual review finds a distinct identity. `QM5_41368` uses the same strict
two-week formation but fades the newest leader; this card follows it.
`QM5_41369` follows only when the same leader persists rather than switches.
`QM5_41367` uses only one common-sign week, and `QM5_41366` admits the disjoint
opposite-sign state. Other matches use deceleration or relative-magnitude
classifications rather than the locked two-week leader rotation.

Verdict:
`DISTINCT_TWO_WEEK_COMMON_SHOCK_STRICT_LEADER_SWITCH_NEWEST_WINNER_CONTINUATION`.

## Authorization Boundary

`g0_status: APPROVED` authorizes deterministic registry and magic allocation,
reference fixtures, one branch-only non-live V5 build, strict Q01, and one
paced logical-basket Q02 enqueue only if both the fresh five-sample CPU average
and maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
