# QUA-1027 DevOps Closeout (2026-05-09)

Issue: QUA-1027 (P5 under QUA-1024)

## Outcome

EA source directory hygiene is complete.

- Removed `QUA-*` artifacts from `framework/EAs/**`.
- Archived artifacts to `docs/ops/QUA-archived/framework/EAs/**`.
- Added ignore guardrails in `.gitignore`:
  - `framework/EAs/*/QUA-*`
  - `framework/EAs/*/*.signal`
- Added idempotent mover script:
  - `infra/scripts/Move-QuaArtifactsOutOfEASourceDirs.ps1`
- Added enforcement guardrails against regression:
  - `infra/monitoring/Test-MainArtifactEnforcer.ps1`
  - `infra/scripts/Assert-CommitAllowlist.ps1`

## Verification

- `framework/EAs/**/QUA-*` is empty.
- Archive report exists:
  - `docs/ops/QUA-archived/qua-1027_move_report_latest.json`

## Delivery Commits

- `282be24d` - archive QUA artifacts from EA source dirs and add mover + ignore rules.
- `960465a5` - block future `framework/EAs/**/QUA-*` reintroduction via enforcement rules.

## Done Comment

Done in commits `282be24d` and `960465a5`. QUA-* artifacts were removed from framework/EAs and archived under docs/ops/QUA-archived/framework/EAs; guardrails added via .gitignore and enforcement scripts to prevent reintroduction. Verification: framework/EAs/**/QUA-* is empty; docs/ops/QUA-archived/qua-1027_move_report_latest.json present.
