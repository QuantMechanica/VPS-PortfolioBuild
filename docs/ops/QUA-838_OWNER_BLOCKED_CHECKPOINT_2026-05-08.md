# QUA-838 DevOps Checkpoint (OWNER Blocked)

- Timestamp: 2026-05-08T13:45:00+02:00
- Issue: QUA-838
- Scope: DevOps + Board Advisor - Quartz POC for Company Reference Vault
- Current status: BLOCKED pending OWNER decision
- Unblock owner: OWNER
- Required unblock action: Approve or reject Quartz POC execution lane and target environment

## Why blocked

Execution cannot proceed without OWNER direction on whether Quartz POC should run now, under which boundary (repo-only docs index vs broader vault ingestion), and whether Board Advisor involvement is approved for this cycle.

## Pre-unblock readiness (completed in this heartbeat)

1. Confirmed no existing `QUA-838` implementation artifacts in repo that would conflict with new POC wiring.
2. Prepared execution checklist and acceptance criteria below so work can start in a single heartbeat after OWNER approval.

## Immediate execution plan after unblock

1. Create `infra/quartz-poc/` scaffold with idempotent bootstrap script (`check-then-act`) and rollback notes.
2. Add `docs/ops/QUA-838_QUARTZ_POC_RUNBOOK.md` with install, verify, and remove flows.
3. Add redaction boundary notes for public/private data handling before any indexing job runs.
4. Add minimal health-check script and sample scheduler entry (disabled by default) for non-production validation.
5. Commit with co-author footer and post commit SHA in close-out comment.

## Acceptance criteria draft

1. Re-runnable setup script completes twice with no drift or destructive side effects.
2. POC index source paths are explicit and exclude forbidden surfaces (`.git/`, live terminals, secrets).
3. Verification command returns deterministic pass/fail output.
4. Rollback path documented and tested once.

## Next action

Await OWNER decision. On approval, execute the plan above in the next heartbeat.
