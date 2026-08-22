# Decision: Q08 fixed-parameter NOT_APPLICABLE semantics

- Date: 2026-08-22
- Status: accepted
- Authority: OWNER-DEC-GATECONTRACT
- Effective: ratifies the current executable behavior

## Decision

For a mechanically fixed-parameter strategy, Q08.5 neighborhood stability and
Q08.7 PBO may emit sub-gate `NOT_APPLICABLE` only when the authoritative runner
proves that the parameter family is structurally non-perturbable.

`NOT_APPLICABLE` is non-punitive at the sub-gate level. It is never a top-level
Q08 verdict and never supplies positive robustness evidence. All applicable
sub-gates still decide the aggregate result, and any computed hard failure keeps
precedence. Missing, malformed, ambiguous, or lineage-invalid evidence does not
qualify as structural proof and remains on its existing invalid/infra path.

## Thresholds and scope

No Q08 threshold changes. This ratifies the behavior documented in
`docs/ops/evidence/2026-07-27_q08_evidence_defects_fix.md`; it does not broaden
the structural classifier or convert could-not-compute evidence into a pass.

## Executable binding

- `framework/scripts/q08_davey/sub_8_5_neighborhood.py`
- `framework/scripts/q08_davey/sub_8_7_pbo.py`
- `framework/scripts/q08_davey/aggregate.py`
- `framework/scripts/tests/test_q08_davey_subgates.py`
