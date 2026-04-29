# QUA-414 Transition Retry Blocked — 2026-04-28

- timestamp_local: 2026-04-28T13:51:21+02:00
- run_id: eeefde82-7992-4766-b6b8-a75032d592cc
- command: Invoke-QUA350IssueTransition.ps1 -IssueId QUA-414 ... -Apply
- result: HTTP 500 Internal server error
- status_change_confirmed: false

Unblock owner/action remains unchanged:
- Owner: Paperclip platform/API owner
- Action: restore PATCH /api/issues/{id} path, then rerun:
  powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/Invoke-QUA350IssueTransition.ps1 -IssueId QUA-414 -StatusPayloadPath docs/ops/QUA-414_ISSUE_STATUS_UPDATE_2026-04-28.json -CommentPath docs/ops/QUA-414_ISSUE_CLOSEOUT_COMMENT_2026-04-28.md -RunId <active_run_id> -Apply
