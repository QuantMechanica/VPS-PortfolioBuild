# DL-033: Main Artifact Enforcer

- Date: 2026-05-01
- Owner: DevOps
- Related issues: QUA-589, QUA-616

## Decision

Adopt a two-layer guard to prevent QUA-generated artifacts from accumulating on the `main` checkout:

1. Pre-commit enforcement on `main` via `.githooks/pre-commit` calling:
   - `infra/scripts/Assert-CommitAllowlist.ps1 -FailOnMainArtifactPaths`
2. Scheduled sentinel every 15 minutes via:
   - `infra/monitoring/Test-MainArtifactEnforcer.ps1`
   - converged by `infra/tasks/Register-QMInfraTasks.ps1` task `QM_MainArtifactEnforcer_15min`

## Blocked path classes on `main`

- `docs/ops/QUA-*_*.{md,json,sha256,txt}`
- Root `QUA-*_*.{md,json,sha256,txt}`
- `artifacts/qua-*/...`
- `**/__pycache__/`
- `.claude/scheduled_tasks.lock`

## Additional hygiene

- `.gitignore` now excludes:
  - `__pycache__/`
  - `**/__pycache__/`
  - `.claude/scheduled_tasks.lock`

## Why

QUA-589 surfaced sustained artifact drift on `C:/QM/repo` main checkout. The pre-commit hook stops local introduction, and the scheduled sentinel catches any bypass/drift.
