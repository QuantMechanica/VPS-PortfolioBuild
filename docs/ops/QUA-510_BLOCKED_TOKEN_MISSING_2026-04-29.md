# QUA-510 Blocked: Missing API Token (2026-04-29)

Block reason:
- `PAPERCLIP_API_TOKEN` is not present in the current runtime environment.
- Without this token, DevOps cannot execute the final Paperclip `PATCH /api/issues/QUA-510` transition call.

Unblock owner:
- Platform/Harness

Unblock action:
1. Inject `PAPERCLIP_API_TOKEN` into the DevOps runtime environment.
2. Execute:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA510DoneTransition.ps1
```

Expected result:
- `QUA-510` transitions to `done`.
- `issue_blockers_resolved` event fires for `QUA-509`.
