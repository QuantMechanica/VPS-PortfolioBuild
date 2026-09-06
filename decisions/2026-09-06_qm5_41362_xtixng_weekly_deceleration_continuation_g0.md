# G0 Decision — QM5_41362 XTI/XNG Weekly Deceleration Continuation

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41362_xtixng-wdecel-cont`
- Strategy ID: `AI-CODEX-XTIXNG-WDECEL-CONT-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41362_xtixng-wdecel-cont_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_weekly_deceleration_continuation_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_RELATIVE_SPREAD_TRANSLATION_RISK`: complete U.S. government
  and peer-reviewed oil/gas evidence plus peer-reviewed futures momentum;
  adverse instability is retained and no alpha or CFD claim transfers.
- R2 `PASS`: synchronized week ends, adjacent returns, strict same signs,
  strict smaller newest magnitude, shared-direction continuation, weekly
  attempt, opposed legs, aggregate risk, hard stops, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 data provides the required inputs.
- R4 `PASS`: deterministic native arithmetic and execution state only.

## Duplicate Decision

The canonical scan found no exact identity and eight fuzzy family matches.
Manual review resolves the family: `QM5_41359` requires a strictly larger
newest same-sign move and fades it; `QM5_41360` requires opposite signs;
`QM5_41358` requires an opposite-sign overshoot; `QM5_41066` applies the same
state to precious metals and fades rather than follows it. Other energy baskets
use different horizons, state objects, sides, or lifecycle rules. The optional
external Wiki root was unavailable and that coverage limit remains visible.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XTIXNG_SAME_SIGN_DECELERATION_CONTINUATION_BASKET`.

## Authorization Boundary

`g0_status: APPROVED` authorizes the card, deterministic registry and magic
allocation, one branch-only non-live V5 build, strict Q01, and one paced
logical-basket Q02 enqueue only if both five-sample CPU average and maximum
remain strictly below 97%. It does not approve efficacy, decorrelation,
certification, portfolio admission, optimization, deployment, live manifests,
`T_Live`, AutoTrading, or live use.
