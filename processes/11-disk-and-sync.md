---
title: Disk and Sync Safety
owner: OWNER
last-updated: 2026-07-22
---

# 11 — Disk and Sync Safety

Disk, repository, report, and sync health are infrastructure gates. They do not
change strategy verdicts.

## Rules

- Keep the canonical repository and all `.git` directories outside Drive sync.
- Alert before free space threatens tester writes, reports, or terminal operation.
- Pause only new affected work under critical pressure; do not kill T_Live or
  unrelated workers.
- Delete only explicit, verified artifact classes under their retention policy.
  Never use unresolved variables or broad recursive targets.
- Prefer recoverable cleanup and verify the resolved absolute path first.
- Backups require manifests and hashes; a copied file without verification is not
  a restore point.
- Sync state never overrides newer verified filesystem/repository state.

Use `infra/monitoring/Invoke-InfraHealthCheck.ps1` for current checks and
`infra/tasks/Register-QMInfraTasks.ps1` for desired task state. Repeated critical
events are reported to OWNER with measurements and a root-cause proposal.
