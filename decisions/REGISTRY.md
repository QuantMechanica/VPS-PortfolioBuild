# Decision Registry

Status: active authority index, 2026-07-22

OWNER is the sole decision authority. Historical decision files may describe an
older operating model; they are evidence of what was recorded then, not current
approval gates.

## Current authority order

1. Explicit current OWNER instruction.
2. `CLAUDE.md` and `docs/ops/PROJECT_CHARTER.md`.
3. `processes/process_registry.md` and the task-specific active runbook.
4. Deterministic gate specifications and version-bound evidence.
5. Historical decision files only when they do not conflict with 1–4.

## Active decision families

| Topic | Canonical document |
|---|---|
| Pipeline phase model | [`docs/ops/PIPELINE_PHASE_SPEC.md`](../docs/ops/PIPELINE_PHASE_SPEC.md) |
| Framework boundary | [`2026-04-26_v5_framework_design.md`](2026-04-26_v5_framework_design.md) |
| Clean-slate V5 boundary | [`2026-04-26_v5_restart_clean_slate.md`](2026-04-26_v5_restart_clean_slate.md) |
| Sub-gate reconstruction provenance | [`2026-04-26_v5_sub_gate_reconstruction.md`](2026-04-26_v5_sub_gate_reconstruction.md) |
| T6 deploy boundary | [`DL-025_t6_deploy_boundary_refinement.md`](DL-025_t6_deploy_boundary_refinement.md) |
| Housekeeping/freeze safety | [`DL-051_housekeeping_freeze_rule.md`](DL-051_housekeeping_freeze_rule.md) |
| Anti-theater evidence gates | [`DL-054_anti_theater_pass_criteria.md`](DL-054_anti_theater_pass_criteria.md) |

## New decisions

Use a date-prefixed ADR with:

- OWNER decision and date;
- problem and options considered;
- exact scope and non-goals;
- affected contracts, code, and tests;
- rollback or supersession rule;
- links to evidence, not an external issue-system identifier.

Update this registry when a decision changes an active authority or technical
contract. Do not rewrite an old decision receipt to make it look current; supersede
it with a new ADR.
