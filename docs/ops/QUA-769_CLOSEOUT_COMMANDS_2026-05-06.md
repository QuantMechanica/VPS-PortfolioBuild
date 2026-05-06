# QUA-769 Closeout Commands (Operator Sheet)

## 1) Regenerate transition payload

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\New-QUA769IssueTransitionPayload.ps1
```

## 2) Validate closeout bundle

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA769Closeout.ps1
```

Expected: `status=ok`

## 3) Verify runtime health scheduler task

```powershell
schtasks /Query /TN "\QM_PythonRuntimeHealth_10min" /V /FO LIST
```

Verify:
- Task exists
- Next Run Time populated
- Last Result `0` after manual/automatic run

## 4) Optional manual trigger

```powershell
schtasks /Run /TN "\QM_PythonRuntimeHealth_10min"
```

## 5) Transition evidence artifact

Use:
- `docs/ops/QUA-769_ISSUE_TRANSITION_PAYLOAD_2026-05-06.json`

As source for issue state update to `done/completed`.
