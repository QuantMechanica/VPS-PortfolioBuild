# G0 Decision — QM5_41368 XTI/XNG Common-Shock Leader-Switch Reversion

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41368_xtixng-cs-leadswitch-rv`
- Strategy ID: `AI-CODEX-XTIXNG-CS-LEADSWITCH-RV-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41368_xtixng-cs-leadswitch-rv_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_common_shock_leader_switch_reversion_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_TWO_WEEK_LEADER_SWITCH_TRANSLATION_RISK`: complete
  peer-reviewed commodity relative-return evidence plus complete government
  and peer-reviewed oil/gas evidence; the two-week common-shock leader-switch
  fade is an explicitly untested QM synthesis.
- R2 `PASS`: three synchronized completed-week endpoints, three-to-five-
  session bounds, two strict same-sign states, strict relative-leader switch,
  newest-winner fade, weekly attempt, aggregate risk, hard stops, and
  lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data supplies every required runtime input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  banned indicator, external runtime feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical scan covered 4,848 registry rows and 1,461 repository cards. It
found no exact identity and returned three expected fuzzy family matches; the
external Strategy Wiki root was unavailable and remains an explicit coverage
limit.

Manual review finds a distinct identity. `QM5_41361` uses only one common-sign
week and does not require a leader switch. `QM5_41367` also uses one week and
follows rather than fades its winner. `QM5_41365` admits the disjoint
opposite-sign state. The two adjacent ratio-return reversal siblings compare
magnitudes, while this rule requires same-sign individual returns in both
weeks and ignores magnitude.

Verdict:
`DISTINCT_TWO_WEEK_COMMON_SHOCK_STRICT_LEADER_SWITCH_NEWEST_WINNER_FADE`.

## Authorization Boundary

`g0_status: APPROVED` authorizes deterministic registry and magic allocation,
reference fixtures, one branch-only non-live V5 build, strict Q01, and one
paced logical-basket Q02 enqueue only if both the fresh five-sample CPU average
and maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
