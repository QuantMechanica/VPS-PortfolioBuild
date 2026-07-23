# Infrastructure Scripts

The scripts in this directory are bounded local utilities. Current scheduling uses
Windows Task Scheduler through `infra/tasks/Register-QMInfraTasks.ps1`.

Primary entry points:

- `Invoke-DwxHourlyCheck.ps1` — run the DWX import/verification state machine.
- `Install-DwxHourlyTask.ps1` — converge only the hourly DWX task.
- `Invoke-InfraAudit.ps1` — produce a read-only infrastructure audit.
- `Remove-RecoveryOrphans.ps1` — age-gated recovery-directory cleanup.

Files named for old QUA work items are historical maintenance helpers unless an
active runbook explicitly selects them. They are not governance authorities and
must not be used to infer current approval state.
