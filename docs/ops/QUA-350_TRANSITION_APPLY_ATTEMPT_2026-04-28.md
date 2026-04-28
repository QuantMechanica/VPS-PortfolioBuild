# QUA-350 Transition Apply Attempt (2026-04-28)

- status: blocked (transport)
- attempted command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA350IssueTransition.ps1 -RunId 83fe31b3-5bb4-4e87-887f-edc78734935b -Apply`
- failure:
  - `Invoke-RestMethod : Unable to connect to the remote server`

## Unblock

- owner: DevOps
- action: run the same command from an environment with reachable Paperclip API base URL, or pass `-PaperclipApiUrl <reachable-url>`.
- expected mutation on success:
  - POST `docs/ops/QUA-350_ISSUE_COMMENT_2026-04-28.md`
  - PATCH issue status to `in_review` via `docs/ops/QUA-350_ISSUE_STATUS_UPDATE_2026-04-28.json`
