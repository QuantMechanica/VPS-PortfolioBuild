# QUA-774 Blocked Heartbeat Runbook (2026-05-08)

## Scope

- Issue: `QUA-774`
- Failure mode: `REPORT_MISSING;INCOMPLETE_RUNS`
- Target: `QM5_1004` on `US500.DWX`, required TFs `H1/H4/D1`

## Canonical Command (manual heartbeat)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA774BlockedHeartbeat.ps1 -RequireExternalSignal
```

This command:
1. Runs `Test-QUA774ExternalUnblockSignal.ps1` first.
2. Short-circuits with `skipped=true` until external unblock signal is ready.
3. When ready, runs the full blocked heartbeat flow:
1. `Run-QUA774BlockerRefresh.ps1`
2. `New-QUA774IssueTransitionPayload.ps1`
3. `Test-QUA774BlockedPackage.ps1`
4. `Test-QUA774HandoffIntegrity.ps1`

External signal artifact:
- `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json`
- Required field to resume: `"ready_to_resume": true`

## Artifacts refreshed by heartbeat

- `docs/ops/QUA-774_P2_REDEPLOY_SUMMARY_<UTCSTAMP>.json`
- `docs/ops/QUA-774_P2_REDEPLOY_SUMMARY_CURRENT.json` (canonical rolling pointer)
- `docs/ops/QUA-774_BLOCKER_STATUS_2026-05-08.json`
- `docs/ops/QUA-774_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json`
- `docs/ops/QUA-774_BLOCKED_COMMENT_2026-05-08.md`
- `docs/ops/QUA-774_BLOCKED_PACKAGE_2026-05-08.sha256`
- `docs/ops/QUA-774_UNBLOCK_REQUEST_2026-05-08.json`

## Scheduler install (optional)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA774BlockedHeartbeatTask.ps1
```

The installed launcher is signal-gated by default (`-RequireExternalSignal`).

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
4. Set `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json` to `"ready_to_resume": true`.
5. Re-run blocked heartbeat; issue can move to `in_review` only when summary `verdict=PASS` and no failure flags remain.
