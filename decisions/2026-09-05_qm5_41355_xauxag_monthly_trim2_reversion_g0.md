# G0 Decision — QM5_41355 XAU/XAG Monthly Fixed-Trim Reversion

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA: `QM5_41355_xauxag-mtrim2-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MTRIM2-RV-20260905_S01`
- Card: `strategy-seeds/cards/approved/QM5_41355_xauxag-mtrim2-rv_card.md`
- Source approval:
  `decisions/2026-09-05_xauxag_monthly_trim2_reversion_source_approval.md`

## Gate findings

- R1 `PASS_WITH_SYNTHESIS_RISK`: the approved source binds a peer-reviewed
  gold/silver relationship, exchange spread construction, and governed
  fixed-trim arithmetic without transferring an alpha or CFD claim.
- R2 `PASS`: synchronized endpoints, adjacent returns, exact sort and trim,
  sign, direction, monthly attempt, opposed legs, aggregate risk, stops, and
  lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XAU/XAG D1 data
  provides the required inputs.
- R4 `PASS`: deterministic native arithmetic and execution state only.

## Duplicate decision

The preallocation receipt returned `FUZZY_MATCH` and no exact identity. Manual
review resolves all candidates: this rule deletes the two most positive and
two most negative monthly ratio returns and equally averages the middle eight.
It does not z-score a level, estimate an OLS residual, compare old/recent
samples, or iteratively redescend. The frozen fixture yields a positive
trimmed mean but negative Hampel and bisquare centers, proving a two-way signal
disagreement with the nearest family members.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XAUXAG_MONTHLY_RATIO_RETURN_FIXED_TWO_PER_TAIL_TRIMMED_MEAN_CONTRARIAN_BASKET`.

## Authorization boundary

`g0_status: APPROVED` authorizes the card, deterministic registry and magic
allocation, reference fixtures, one branch-only non-live V5 build, strict Q01,
and one paced logical-basket Q02 enqueue if the five-sample CPU window remains
strictly below 97% on both average and maximum. It does not approve efficacy,
decorrelation, certification, portfolio admission, optimization, deployment,
live manifests, `T_Live`, AutoTrading, or live use.
