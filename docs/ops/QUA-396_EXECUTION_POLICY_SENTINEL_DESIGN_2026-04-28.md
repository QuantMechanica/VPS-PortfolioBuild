## QUA-396 — Class-2 executionPolicy sentinel routine design

Status: implemented (monitor + scheduler installer + infra task wiring)

### Objective
- Detect missing `executionPolicy` on Class-2 Strategy Card issues (DL-030 scope).
- Keep default mode non-mutating (detect/report only), with optional controlled auto-patch mode.

### Implemented components
- `infra/monitoring/Test-Class2ExecutionPolicySentinel.ps1`
  - Queries Paperclip issues for active statuses.
  - Filters Class-2 candidates by:
    - project `b2adcc7f-064f-47c7-8563-d1c917639231` (V5 Strategy Research)
    - child issue (`parentIssueId` or `parentId` set)
    - title pattern `^SRC\d{2}_S\d+[a-z]?\b`
    - excludes explicit identifiers list (default includes `QUA-236`)
  - Flags missing/invalid `executionPolicy` as `critical`.
  - Optional `-ApplyMissingPolicy` PATCHes interim Class-2 policy per DL-030:
    - review participants: CEO agent + `local-board`
    - requires `X-Paperclip-Run-Id`.
  - Writes JSON output: `C:\QM\logs\infra\health\class2_execution_policy_sentinel_latest.json`.

- `infra/scripts/Install-Class2ExecutionPolicySentinelTask.ps1`
  - Idempotent Task Scheduler installer (`Register-ScheduledTask -Force`).
  - Default task: `QM_Class2ExecutionPolicySentinel_60min`.
  - Supports `-PreviewOnly`, `-RunNow`, and optional `-ApplyMissingPolicy`.

- `infra/tasks/Register-QMInfraTasks.ps1`
  - Adds converged registration of `QM_Class2ExecutionPolicySentinel_60min`.

- `infra/README.md`
  - Added script and installer documentation and install command.

### Verification run (this heartbeat)
- Installer preview:
  - `Install-Class2ExecutionPolicySentinelTask.ps1 -PreviewOnly`
  - Result: valid action/trigger/principal configuration.
- Sentinel check:
  - `Test-Class2ExecutionPolicySentinel.ps1`
  - Result: `critical` with missing-policy detections in live issue set (expected for current backlog state).

### Next action
- CTO/CEO decision on whether to run sentinel in detect-only mode or enable `-ApplyMissingPolicy` in scheduled task args.
