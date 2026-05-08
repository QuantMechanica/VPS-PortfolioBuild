# QUA-774 Blocked Heartbeat Runbook (2026-05-08)

## Scope

- Issue: `QUA-774`
- Failure mode: `REPORT_MISSING;INCOMPLETE_RUNS`
- Target: `QM5_1004` on `US500.DWX`, required TFs `H1/H4/D1`

## Canonical Command (manual heartbeat)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA774BlockedHeartbeat.ps1
```

This command runs:
1. `Run-QUA774BlockerRefresh.ps1`
2. `New-QUA774IssueTransitionPayload.ps1`
3. `Test-QUA774BlockedPackage.ps1`

## Artifacts refreshed by heartbeat

- `docs/ops/QUA-774_P2_REDEPLOY_SUMMARY_<UTCSTAMP>.json`
- `docs/ops/QUA-774_P2_REDEPLOY_SUMMARY_CURRENT.json` (canonical rolling pointer)
- `docs/ops/QUA-774_BLOCKER_STATUS_2026-05-08.json`
- `docs/ops/QUA-774_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json`
- `docs/ops/QUA-774_BLOCKED_COMMENT_2026-05-08.md`

## Scheduler install (optional)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA774BlockedHeartbeatTask.ps1
```

Preview only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA774BlockedHeartbeatTask.ps1 -PreviewOnly
```

## Unblock owner and required action

- Owner: DWX source acquisition + import pipeline owner
- Actions:
1. Import `US500.DWX` history/ticks into `T1`.
2. Sync `US500.DWX` from `T1` to `T2..T5`.
3. Re-run P2 redeploy for `QM5_1004` / `US500`.
4. Re-run blocked heartbeat; issue can move to `in_review` only when summary `verdict=PASS` and no failure flags remain.
