# QUA-774 DevOps Handoff (2026-05-08)

## Current State

- Issue: `QUA-774`
- Status: `blocked`
- Reason: `REPORT_MISSING;INCOMPLETE_RUNS`
- Affected target: `QM5_1004` + `US500.DWX` (`H1/H4/D1`)

## Canonical Execution

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA774BlockedHeartbeat.ps1
```

## Canonical Artifacts

- `docs/ops/QUA-774_P2_REDEPLOY_SUMMARY_CURRENT.json`
- `docs/ops/QUA-774_BLOCKER_STATUS_2026-05-08.json`
- `docs/ops/QUA-774_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json`
- `docs/ops/QUA-774_BLOCKED_COMMENT_2026-05-08.md`
- `docs/ops/QUA-774_BLOCKED_PACKAGE_2026-05-08.sha256`

## Integrity Checks

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA774BlockedPackage.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA774HandoffIntegrity.ps1
```

Expected now:
- blocked package check -> `status=ok ... evidence=QUA-774_P2_REDEPLOY_SUMMARY_CURRENT.json`
- handoff integrity -> `summary=ok checked=13 failed=0`

## Unblock Owner / Required Action

- Owner: DWX source acquisition + import pipeline owner
- Required:
1. Import `US500.DWX` history/ticks into `T1`.
2. Sync symbol from `T1` to `T2..T5`.
3. Re-run `QM5_1004` P2 redeploy for `US500`.
4. Re-run blocked heartbeat and move issue to `in_review` only after `verdict=PASS`.

## DevOps Commit Trail (this issue)

- `da289d2c` add P2 redeploy summary checker
- `f89a705b` add blocked summary + real-path evidence
- `59a0f54e` add blocker-status generator
- `68298867` add blocker refresh runner
- `e73d6824` add issue transition payload generator
- `3963eff2` add blocked package coherence test
- `5aeb74ef` add one-command blocked heartbeat runner
- `f8f565f3` add scheduled-task installer
- `753ac68b` add blocked heartbeat runbook
- `d80947f7` add handoff integrity manifest/verifier
- `b046870e` integrate integrity into heartbeat wrapper
- `c3b9d5b9` stabilize canonical CURRENT evidence pointer
