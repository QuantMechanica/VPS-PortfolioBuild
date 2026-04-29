# PC1-00 Drive/Git Hard-Fence Evidence (2026-04-27)

## Command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Test-DriveGitExclusion.ps1 -PrimaryRepoForWorktrees C:\QM\repo -IncludeGitWorktrees
```

## Result

- Status: `ok`
- Check: `drive_git_exclusion_hard_fence`
- Evidence JSON: `C:\QM\logs\infra\health\drive_git_exclusion_latest.json`
- Alert webhook enabled: `false` (no `QM_ALERT_WEBHOOK_URL` configured in this run context)

## Covered Repo Roots

- `C:\QM\repo`
- `C:\QM\worktrees\cto`
- `C:\QM\worktrees\devops`
- `C:\QM\worktrees\docs-km`
- `C:\QM\worktrees\pipeline-operator`
- `C:\QM\worktrees\qua95-clean`

## Notes

- Worktree `.git` file pointers resolved into `C:\QM\repo\.git\worktrees\*` and were verified outside detected Drive sync roots.
- Recurring task target remains `QM_DriveGitExclusion_15min`.
