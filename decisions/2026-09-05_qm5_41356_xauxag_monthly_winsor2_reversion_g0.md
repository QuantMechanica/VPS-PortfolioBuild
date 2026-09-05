# G0 Decision — QM5_41356 XAU/XAG Monthly Fixed-Tail Winsorized Reversion

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41356_xauxag-mwinsor2-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MWINSOR2-RV-20260905_S01`
- Card: `strategy-seeds/cards/approved/QM5_41356_xauxag-mwinsor2-rv_card.md`
- Source approval:
  `decisions/2026-09-05_xauxag_monthly_winsor2_reversion_source_approval.md`

## Gate Findings

- R1 `PASS_WITH_SYNTHESIS_RISK`: peer-reviewed gold/silver relationship,
  exchange spread construction, and governed Winsor arithmetic without an
  transferred alpha or CFD claim.
- R2 `PASS`: synchronized endpoints, adjacent returns, sort, exact boundary
  replacement, sign, direction, monthly attempt, opposed legs, aggregate
  risk, hard stops, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XAU/XAG D1 data
  provides the required inputs.
- R4 `PASS`: deterministic native arithmetic and execution state only.

## Duplicate Decision

The corrected-root scan returned `FUZZY_MATCH` and no exact identity. Manual
review resolves the family: this rule replaces sorted indexes `0,1` by `2`
and `10,11` by `9`, then averages twelve capped observations. It neither
deletes tails nor iteratively reweights residuals. The frozen fixture yields
a negative Winsor mean but positive trimmed mean, proving opposed pair sides.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XAUXAG_MONTHLY_RATIO_RETURN_FIXED_TWO_PER_TAIL_WINSORIZED_MEAN_CONTRARIAN_BASKET`.

## Authorization Boundary

`g0_status: APPROVED` authorizes the card, deterministic registry and magic
allocation, reference fixtures, one branch-only non-live V5 build, strict Q01,
and one paced logical-basket Q02 enqueue only if both five-sample CPU average
and maximum remain strictly below 97%. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
