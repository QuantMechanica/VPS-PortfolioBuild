# QUA-93 Blocker Refresh Task Smoke (2026-04-27)

## Scope

Validate the new QUA-93 blocked-state automation without registering a live scheduled task.

Scripts under test:
- `infra/scripts/Run-QUA93BlockerRefresh.ps1`
- `infra/scripts/Install-QUA93BlockerRefreshTask.ps1`

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA93BlockerRefresh.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA93BlockerRefreshTask.ps1 -PreviewOnly
```

## Observed Outputs

Runner log (`infra/smoke/qua93_blocker_refresh_task.log`):

```text
[2026-04-27T09:54:47+02:00] start task=QM_QUA93_BlockerRefresh
[2026-04-27T09:55:05+02:00] success task=QM_QUA93_BlockerRefresh
```

Installer preview output:

```text
preview_task_name=QM_QUA93_BlockerRefresh
preview_interval_minutes=60
preview_log_path=C:\QM\repo\infra\smoke\qua93_blocker_refresh_task.log
preview_action=PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\scripts\Run-QUA93BlockerRefresh.ps1" -RepoRoot "C:\QM\repo" -LogPath "C:\QM\repo\infra\smoke\qua93_blocker_refresh_task.log" -TaskName "QM_QUA93_BlockerRefresh"
```

## Artifact Refresh Confirmed

Runner execution refreshed:
- `lessons-learned/evidence/2026-04-27_qua93_xauusd_rerun_evidence.json`
- `docs/ops/QUA-93_XAUUSD_BLOCKER_STATUS_2026-04-27.json`
- `docs/ops/QUA-93_BLOCKED_COMMENT_2026-04-27.md`

Current state remains blocked/defer (`verify_exit_code=1`, `XAUUSD.DWX FAIL_tail_mid_bars`, `bars_got=0`).

## Decision

- Automation path is validated.
- Scheduled task registration intentionally not performed in this smoke step (preview only).
