# DL-003 V5 Framework Review (QUA-149)

Date: 2026-04-27
Issue: QUA-149
Spec reviewed: `framework/V5_FRAMEWORK_DESIGN.md`

## Scope

This audit fulfills QUA-149 Step 1:
- read `framework/V5_FRAMEWORK_DESIGN.md` end-to-end
- grade every script reference in the spec as `[SPEC ONLY - NOT IMPLEMENTED]`, `[PARTIAL]`, or `[IMPLEMENTED]`
- issue explicit Phase 2 GO/NO-GO recommendation

## Evidence Baseline

Observed repository state at audit time:
- `framework/` contains only `README.md` and `V5_FRAMEWORK_DESIGN.md`.
- `framework/scripts/` does not exist.
- No `framework/include/`, `framework/templates/`, `framework/registry/`, `framework/tests/` implementation assets exist yet.

## Script Reference Audit

| Script reference in spec | Spec lines | Expected location | Observed state | Status | Notes |
|---|---:|---|---|---|---|
| `framework/scripts/strip_dwx_at_deploy.ps1` | 28 | `framework/scripts/strip_dwx_at_deploy.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | Required to enforce `.DWX` strip boundary at deploy packaging only. |
| `framework/scripts/run_smoke.ps1` | 29, 136, 728-737, 781 | `framework/scripts/run_smoke.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | Critical for Model-4 smoke gate and P1 pass criteria. |
| `framework/scripts/build_check.ps1` | 32, 45, 135, 210-215, 425, 717-726, 780, 826 | `framework/scripts/build_check.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | Hard-rule enforcement anchor (ML ban, import guard, magic checks, set validation). |
| `compile_one.ps1` | 133, 699-709, 779, 824 | `framework/scripts/compile_one.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | `metaeditor.exe` strict compile path not yet present. |
| `compile_all.ps1` | 134, 711-715, 721 | `framework/scripts/compile_all.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | Aggregate compile gate currently absent. |
| `validate_setfile.ps1` | 137, 302, 723, 739-744 | `framework/scripts/validate_setfile.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | Set header/schema enforcement not yet implemented. |
| `framework/scripts/sync_brand_tokens.ps1` / `scripts/sync_brand_tokens.ps1` | 400, 761, 778 | `framework/scripts/sync_brand_tokens.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | `QM_Branding.mqh` auto-generation path not yet available. |
| `scripts/brand_report.ps1` | 782 | `framework/scripts/brand_report.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | Report post-processing script not implemented. |
| `framework/scripts/rotate_logs.ps1` | 796 | `framework/scripts/rotate_logs.ps1` | file missing | `[SPEC ONLY - NOT IMPLEMENTED]` | Log rollover operation exists only in design text. |

## Recommendation

Decision: **GO for Phase 2 entry (implementation phase)**.

Reasoning:
- The missing scripts are the intended deliverables of Phase 2, not a contradiction that prevents starting Phase 2.
- The spec is sufficiently explicit to execute in strict sequence (Implementation Order, steps 1-25).
- Blocking Phase 2 until these scripts exist is circular, because Phase 2 is where they are created.

Operational caveat (hard):
- **NO-GO for production-like pipeline execution** until at least implementation steps 20-24 are complete (`compile_one`, `build_check`, `run_smoke`, smoke regression assets) and validated on T1 per spec.

## Immediate Next Actions (per spec)

1. Open child issues (one per step, 25 total) under QUA-149.
2. Execute strictly in order, starting with Step 1 `QM_Errors.mqh`.
3. Keep each child issue evidence-linked and only mark done when artifact exists and runs where required.
