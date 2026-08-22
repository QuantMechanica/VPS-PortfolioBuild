# Ratified Q01, Q08, and Q10 gate contracts

Status: current repository contract mirror, ratified 2026-08-22 under
`OWNER-DEC-GATECONTRACT`.

The canonical Company Reference Vault was unavailable to the headless session.
This repository document is the durable code-adjacent mirror and does not
silently rewrite historical evidence.

## Q01 build smoke

The normal contract is a deterministic, in-universe smoke with at least one
trade before Q02 fanout. A zero-trade smoke is blocking.

The only waiver is tester-fleet saturation. The durable build result must use
the compatibility marker `deferred_p2_smoke` and contain explicit capacity
evidence from the same attempt. Missing smoke data and generic headless or
framework-error deferrals fail closed. A valid waiver transfers the first
runtime test to paced Q02; it is not a PASS claim.

Decision: `decisions/2026-08-22_q01_smoke_saturation_waiver.md`.

## Q08 fixed-parameter sub-gates

Q08.5 and Q08.7 may be `NOT_APPLICABLE` only after authoritative structural
proof that no eligible parameter can be perturbed. The label is sub-gate-only,
non-punitive, and supplies no positive evidence. Computed failures and invalid
evidence retain their existing precedence and disposition.

Decision: `decisions/2026-08-22_q08_fixed_parameter_not_applicable.md`.

## Q10 recency

The recency switch applies to every Q10 work item created at or after
2026-09-01 00:00 UTC. Earlier rows remain shadow-only.

For an assessable post-cutoff base PASS, trailing-24-month PF must be at least
1.0 and half-vs-half decline must be below 40%. Insufficient observations are
`UNKNOWN`; evidence more than nine months old is `STALE_WINDOW`. Those two
states preserve the base verdict but block deployment. Cohort identity comes
only from immutable `work_items.created_at`.

Decision: `decisions/2026-08-22_q10_recency_cohort_activation.md`.

## Change control

These records ratify or narrow existing semantics. They do not change any gate
threshold. Future threshold or scope changes require a new dated OWNER decision,
code and test changes, and an updated matrix artifact.
