# QM5_41208 Card Schema Normalization Amendment

Date: 2026-08-30

Decision: `APPROVED_EDITORIAL_NORMALIZATION_NO_MECHANIC_CHANGE`.

The OWNER-authorized G0 decision remains
`decisions/2026-08-30_qm5_41208_xng_seasonal_surprise_reversion_g0.md`.
This amendment records the post-decision heading normalization required by the
canonical G0, Card-v2 execution-contract, and EA spec validators before build.

## Bound Card

- card: `strategy-seeds/cards/approved/QM5_41208_xng-seas-surprise-rv_card.md`
- original G0-bound SHA-256:
  `80C7AF151BF3398DB92ED2FF7F8395BC0AEDFDE536ED539F3654522C5B9AC574`
- normalized SHA-256:
  `A813E8D958104322E52998ECD9ADE00BB8DA6CFB163E833B88544049BB36B951`

The normalized card adds explicit source-defined/QM-interpretation boundaries,
canonical numbered rule headings, execution overrides, exit precedence,
runtime dependency, and falsification/requalification headings. It does not
change the symbol, clock, endpoint, realized-sample exclusion, earlier-year
membership, five-sample floor, arithmetic mean, n-1 deviation, z threshold,
side, attempt, risk, stop, spread, news, Friday-close, or lifecycle rule.

## Validation

- `skill_card_schema_lint.py`: PASS, no ML hits or missing sections.
- `skill_g0_card_lint.py`: PASS, no missing sections.
- `execution_contract_lint.py --as-of 2026-08-29 --card ...`: PASS with zero
  issues; the explicit as-of binds the repository calendar snapshot and avoids
  unrelated next-day expiry noise.
- local `docs/strategy_card.md` is byte-identical to the normalized approved
  card.

This amendment authorizes no result-dependent mechanic, Q02 parameter change,
live artifact, `T_Live` action, portfolio-gate mutation, or AutoTrading action.
