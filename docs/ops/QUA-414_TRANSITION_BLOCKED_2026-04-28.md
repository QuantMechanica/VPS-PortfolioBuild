# QUA-414 Transition Blocked — 2026-04-28

## Attempt
- Script: `infra/scripts/Invoke-QUA350IssueTransition.ps1`
- Issue: `QUA-414`
- RunId: `e24bf20b-106f-4fc3-9820-666a6d4cf5ac`
- Action: PATCH issue status + closeout comment (`in_review`)

## Result
- API error: `Internal server error` (HTTP 500 via `Invoke-RestMethod`).
- No confirmation returned that issue state/comment was updated.

## Prepared Payloads
- `docs/ops/QUA-414_ISSUE_STATUS_UPDATE_2026-04-28.json`
- `docs/ops/QUA-414_ISSUE_CLOSEOUT_COMMENT_2026-04-28.md`

## Unblock Owner / Action
- **Owner:** Paperclip platform/API owner
- **Action:** restore `/api/issues/{id}` PATCH availability, then rerun:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/Invoke-QUA350IssueTransition.ps1 -IssueId QUA-414 -StatusPayloadPath docs/ops/QUA-414_ISSUE_STATUS_UPDATE_2026-04-28.json -CommentPath docs/ops/QUA-414_ISSUE_CLOSEOUT_COMMENT_2026-04-28.md -RunId <active_run_id> -Apply`

## Next Action (ready)
- On API recovery, replay the exact command above to publish closeout comment + status transition.
