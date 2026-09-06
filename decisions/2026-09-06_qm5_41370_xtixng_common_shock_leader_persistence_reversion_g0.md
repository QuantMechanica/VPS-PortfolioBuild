# G0 Decision — QM5_41370 XTI/XNG Common-Shock Leader-Persistence Reversion

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41370_xtixng-cs-leadpersist-rv`
- Strategy ID: `AI-CODEX-XTIXNG-CS-LEADPERSIST-RV-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41370_xtixng-cs-leadpersist-rv_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_common_shock_leader_persistence_reversion_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_TWO_WEEK_LEADER_PERSISTENCE_REVERSION_TRANSLATION_RISK`:
  complete peer-reviewed commodity evidence plus government and peer-reviewed
  oil/gas evidence; the exact reversion is explicitly untested.
- R2 `PASS`: synchronized three-week endpoints, two strict common-sign states,
  same-leader persistence, winner fade, attempt, risk, stops, and lifecycle
  are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data supplies all runtime market inputs.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  banned indicator, external runtime feed, grid, martingale, or pyramid.

## Duplicate Decision

The canonical scan covered 4,850 registry rows and 1,463 repository cards. It
found no exact identity and returned five expected fuzzy family matches; the
external Strategy Wiki root was unavailable and remains explicit.

Manual review finds a distinct identity. `QM5_41369` follows rather than fades
the identical formation. `QM5_41368` requires a leader switch rather than
persistence. `QM5_41361` uses only one common-sign week. `QM5_41365` requires
opposite within-week leg signs. `QM5_41367` is one-week continuation.

Verdict:
`DISTINCT_TWO_WEEK_COMMON_SHOCK_STRICT_SAME_LEADER_PERSISTENCE_REVERSION`.

## Authorization Boundary

`g0_status: APPROVED` authorizes deterministic registry and magic allocation,
reference fixtures, one branch-only non-live V5 build, strict Q01, and one
paced logical-basket Q02 enqueue only if both the fresh five-sample CPU average
and maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
