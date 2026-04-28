# QUA-350 Transition Apply Attempt (2026-04-28)

- status: resolved
- attempted command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA350IssueTransition.ps1 -RunId 83fe31b3-5bb4-4e87-887f-edc78734935b -Apply`
- failure:
  - `Invoke-RestMethod : Unable to connect to the remote server`

## Unblock

- owner: DevOps
- action taken:
  - switched API base to `PAPERCLIP_API_URL` (`http://127.0.0.1:3101`)
  - used issue UUID (`$env:PAPERCLIP_TASK_ID`) instead of identifier alias
  - patched issue with required inline `comment` + `status` payload
- result:
  - QUA-350 status moved to `in_review`
  - comment IDs posted during resolution: `6f8b9171-40d7-45bc-98d8-0e51e7d9e6be`, `1931d125-f666-4067-9a2a-a2a753ee9135`
