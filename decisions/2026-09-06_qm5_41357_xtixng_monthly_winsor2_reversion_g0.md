# G0 Decision — QM5_41357 XTI/XNG Monthly Fixed-Tail Winsorized Reversion

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41357_xtixng-mwinsor2-rv`
- Strategy ID: `AI-CODEX-XTIXNG-MWINSOR2-RV-20260906_S01`
- Card: `strategy-seeds/cards/approved/QM5_41357_xtixng-mwinsor2-rv_card.md`
- Source approval:
  `decisions/2026-09-06_xtixng_monthly_winsor2_reversion_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_SYNTHESIS_RISK`: complete U.S. government and peer-reviewed
  oil/gas relationship evidence, including adverse instability, plus governed
  Winsor arithmetic without a transferred alpha or CFD claim.
- R2 `PASS`: synchronized endpoints, adjacent returns, sort, exact boundary
  replacement, sign, direction, monthly attempt, opposed legs, aggregate
  risk, hard stops, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTI/XNG D1 data
  provides the required inputs.
- R4 `PASS`: deterministic native arithmetic and execution state only.

## Duplicate Decision

The corrected-root scan returned `FUZZY_MATCH` and no exact identity. Manual
review resolves the family: `QM5_41192` uses one completed month of daily H-L
returns; this rule uses twelve monthly oil/gas ratio returns and fixed-tail
capping. `QM5_41340` owns only WTI and follows its annual sign behind a read-
only XNG veto; this rule owns two opposed energy legs and fades the robust
relative state. `QM5_41356` shares the estimator but owns a precious-metals
carrier. The frozen vector also distinguishes Winsorization from deletion and
iterative residual weighting.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XTIXNG_MONTHLY_RATIO_RETURN_FIXED_TWO_PER_TAIL_WINSORIZED_MEAN_CONTRARIAN_BASKET`.

## Authorization Boundary

`g0_status: APPROVED` authorizes the card, deterministic registry and magic
allocation, reference fixtures, one branch-only non-live V5 build, strict Q01,
and one paced logical-basket Q02 enqueue only if both five-sample CPU average
and maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
