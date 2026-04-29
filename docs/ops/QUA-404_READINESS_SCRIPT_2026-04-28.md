# QUA-404 Readiness Check Script

Path: `infra/scripts/Test-QUA404Readiness.ps1`

## Purpose

Single-command blocker/readiness check for Development start on `SRC04_S05`.

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA404Readiness.ps1
```

Optional repo root override:

```powershell
powershell -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA404Readiness.ps1 -RepoRoot C:\QM\repo
```

## Ready Criteria

- Card exists and is `status: APPROVED`
- Card `ea_id` is allocated (not `TBD`)
- Registry row exists for `SRC04_S05` + `lien-inside-day-breakout`

If all pass, `blocked=false` and next action is implementation+compile for CTO review.
