# QUA-420 Issue Transition Apply Failure (2026-04-28)

## What was attempted
Used existing transition helper:
- `infra/scripts/Invoke-QUA350IssueTransition.ps1`

Attempt 1:
- API base: `http://127.0.0.1:3100`
- IssueId: `QUA-420`
- RunId: `44eeaf4f-1628-4365-8ddb-3759932eb8d7`
- Result: HTTP 500 `{"error":"Internal server error"}`

Attempt 2:
- API base: `http://127.0.0.1:3100`
- IssueId: `06474c21-aa09-4756-b46e-9d7c6828e5f1` (`$PAPERCLIP_TASK_ID`)
- RunId: `44eeaf4f-1628-4365-8ddb-3759932eb8d7`
- Result: HTTP 500 `{"error":"Internal server error"}`

## Payload files used
- `docs/ops/QUA-420_ISSUE_STATUS_UPDATE_2026-04-28.json`
- `docs/ops/QUA-420_ISSUE_COMMENT_2026-04-28.md`

## Impact
Repo artifacts for blocked state and CTO handoff are complete, but issue-system status/comment apply failed due to backend error.

## Unblock owner/action
- Owner: DevOps / Paperclip platform owner
- Action: inspect server logs for PATCH `/api/issues/{id}` failures for run id `44eeaf4f-1628-4365-8ddb-3759932eb8d7`, then re-run transition apply using existing payload files.

Attempt 3:
- API base: http://127.0.0.1:3101
- IssueId: 06474c21-aa09-4756-b46e-9d7c6828e5f1 (`$PAPERCLIP_TASK_ID`)
- RunId: 44eeaf4f-1628-4365-8ddb-3759932eb8d7
- Result: HTTP 500 {"error":"Internal server error"}

Additional API diagnostic:
- Endpoint: POST /api/issues/QUA-420/comments
- Method: curl direct (JSON body with `comment` + `resume`)
- Result: HTTP 500 {"error":"Internal server error"}
- Conclusion: issue-mutation endpoints are server-failing; read endpoints remain healthy.
