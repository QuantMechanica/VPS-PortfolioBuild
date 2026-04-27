# Framework Artifact Retention Policy

Date: 2026-04-27
Owner: CTO
Issue: QUA-186
Status: APPROVED + IMPLEMENTED

## Context

`QUA-180` intentionally committed staged framework artifacts to satisfy the urgent commit-pass. The following generated artifacts are currently tracked:

- `framework/build/step23_test/sample_report.htm`
- `framework/build/step23_test/sample_report.htm.bak`
- `framework/templates/EA_Skeleton.ex5`
- `framework/tests/smoke/QM5_1001_framework_smoke.ex5`

This follow-up defines steady-state source-of-truth retention.

## Decision

1. `framework/build/` is non-source generated output and is gitignored.
2. The four explicitly approved generated files are gitignored and de-tracked:
   - `framework/build/step23_test/sample_report.htm`
   - `framework/build/step23_test/sample_report.htm.bak`
   - `framework/templates/EA_Skeleton.ex5`
   - `framework/tests/smoke/QM5_1001_framework_smoke.ex5`
3. Source-of-truth remains `.mq5`, `.mqh`, `.set`, scripts, and decision/evidence docs.
4. CI/build evidence is carried by logs/reports under evidence/report paths, not committed binaries.

## Git Policy Applied

Add to root `.gitignore`:

```gitignore
framework/build/
framework/build/step23_test/sample_report.htm
framework/build/step23_test/sample_report.htm.bak
framework/templates/EA_Skeleton.ex5
framework/tests/smoke/QM5_1001_framework_smoke.ex5
```

## De-Tracking Executed

After explicit CEO confirmation (Hard Rule: file-deletion/de-tracking requires explicit OK), de-tracked the four known generated files:

- `framework/build/step23_test/sample_report.htm`
- `framework/build/step23_test/sample_report.htm.bak`
- `framework/templates/EA_Skeleton.ex5`
- `framework/tests/smoke/QM5_1001_framework_smoke.ex5`

No filesystem deletion was performed; this is index de-tracking only.

## Rationale

- Reduces repo noise and churn from non-deterministic build outputs.
- Avoids binary diffs in source control.
- Aligns implementation with `framework/V5_FRAMEWORK_DESIGN.md` statement that `framework/build/` is gitignored.
- Preserves auditable evidence through committed logs/decision records, not compiled artifacts.

## Approval Evidence

- CEO approval comment: `c2891fa7-54fc-41e9-9915-ca892639bf37` on [QUA-186](/QUA/issues/QUA-186), dated 2026-04-27.
- Approval instruction explicitly authorized immediate execution without waiting for interaction-card state flip.
