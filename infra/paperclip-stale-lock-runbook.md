# Paperclip Stale Lock Runbook (QUA-24)

## Scope

This runbook covers Pipeline-Operator stale ownership locks on issue execution fields:

- `checkoutRunId`
- `executionRunId`
- `executionAgentNameKey`
- `executionLockedAt`

## Symptom

- New wake run starts with a new `PAPERCLIP_RUN_ID`.
- Any mutating API call (`PATCH /issues/:id`, comment write that needs checkout ownership, or `POST /issues/:id/release`) returns 409 ownership conflict.
- Issue still shows legacy lock values from an earlier dead/stuck run.

## Immediate recovery (safe manual path)

1. `PATCH /api/issues/{issueId}` with assignee clear only (`assigneeAgentId: null`) and no comment in that request.
2. `PATCH /api/issues/{issueId}` set assignee back to the intended agent, again no comment in that request.
3. Trigger a fresh wake for the assignee (normal assignment wake or comment mention).

Important: Use PATCH-only for the assignee cycle. Do not bundle comment text in the same PATCH payload.

## Known side-effect (2026-04-26 observed)

- If a non-assignee run posts a comment after reassignment, lock metadata can re-attach to the prior run for the same `executionAgentNameKey`.
- Operational workaround: run assignee-cycle as pure PATCH operations first, then comment only after the new assignee run has re-established ownership.

## Platform-side fix status

- Upstream Paperclip service patch (local `C:\QM\paperclip\app`) now reconciles stale `checkoutRunId` to the current run when `executionRunId` already belongs to that run.
- This removes the recurring 409 path where execution ownership had moved but checkout ownership had not.
- Upstream watchdog patch (QUA-67 / DEVOPS-008) now matches stale-run evaluation history by any of:
  - `originId = runId`
  - `originRunId = runId`
  - `originFingerprint = stale_active_run:{companyId}:{runId}`
- This blocks duplicate stale-run evaluation issue creation when source-derivation/cloning paths preserve `originRunId` or fingerprint but clear `originId` (common on weekend-style silent-run loops).

## Optional watchdog (company-side mitigation)

If upstream upgrade is delayed, run a periodic watchdog:

- Query `in_progress` issues assigned to automation agents.
- Flag issue when `executionLockedAt` age > threshold and no active recovery progress.
- Auto-open a child issue with:
  - issue id
  - lock age
  - current `checkoutRunId` / `executionRunId`
  - suggested PATCH-only assignee-cycle recovery

Do not force-clear T6-related issues without OWNER/LiveOps approval gates.

### Scripted watchdog

- Script: `C:\QM\repo\infra\monitoring\Invoke-PaperclipStaleLockWatchdog.ps1`
- Default behavior is monitor-only.
- Optional `-AutoRecover` executes the same PATCH-only assignee-cycle described above.
- Use `-AssigneeAgentId <agent-id>` (defaults to `PAPERCLIP_AGENT_ID`) for deterministic lock visibility on large issue sets.
- Use `-PaperclipRunId <run-id>` (defaults to `PAPERCLIP_RUN_ID`) so mutating calls carry the current heartbeat run trace.
- `-AllowedAssigneeAgentIds` is optional; if omitted, the script auto-uses `-AssigneeAgentId`.
- Lock classes:
  - `orphaned_lock`: stale lock with `activeRun=null`
  - `stale_running_lock`: issue still points at an old `activeRun` long past expected runtime (age from `executionLockedAt` or fallback `activeRun.startedAt`)
- Mutating calls include `X-Paperclip-Run-Id` by design.

Examples:

```powershell
# monitor only
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Invoke-PaperclipStaleLockWatchdog.ps1 -StaleAfterMinutes 15

# explicit auto-recover mode (use only for approved scopes)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Invoke-PaperclipStaleLockWatchdog.ps1 -StaleAfterMinutes 15 -AutoRecover
```
