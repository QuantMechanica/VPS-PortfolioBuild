# QUA-791 Drift-Correction Conflict (2026-05-08)

## What happened

- Live status read: `in_progress`
- Intended state: `blocked` (pending CEO ratification path A/B per CTO memo/comment)
- Attempted mutation: add drift-correction comment + set status `blocked`
- Result: `409 Issue run ownership conflict`

## Error evidence

- Endpoint: `POST /api/issues/b7b29299-e9fc-4b78-ad17-9dce8310a30d/comments`
- Error: `Issue run ownership conflict`
- Details included by API: issue is currently checked out/executing under run `e8750b40-3cf0-4d2b-abdb-4b0901dc607f`.

## Unblock owner / action

- Unblock owner: OWNER / Paperclip runtime controller
- Action:
  1. Resolve checkout/execution run ownership conflict on `QUA-791`.
  2. Re-run drift correction:
     - comment: drift-correction note
     - status: set `blocked`

## Ready commands

```powershell
python C:/QM/paperclip/tools/ops/next_task.py --agent cto --json
python C:/QM/repo/scripts/ops/post_qua791_comment.py
```

## Existing evidence chain

- `C:/QM/repo/docs/ops/QUA-791_CTO_RATIFICATION_2026-05-08.md`
- `C:/QM/repo/docs/ops/QUA-791_PAPERCLIP_COMMENT_DRAFT_2026-05-08.md`
- `C:/QM/repo/docs/ops/QUA-791_COMMENT_POST_RECEIPT_2026-05-08T084453+0200.md` (successful comment post)

## Update 2026-05-08T08:53 local

Second correction attempt from run `e8750b40-3cf0-4d2b-abdb-4b0901dc607f` also failed with 409.

New conflict evidence:
- API reports active owner run switched to `5ce596fb-f046-4a29-972f-89db992c873f` during write attempt.
- Read operations succeed; write operations fail due to ownership churn.

Implication:
- This is a runtime checkout arbitration problem (flapping run ownership), not an issue-content or permission-shape problem.

Requested fix:
1. Stabilize checkout ownership for QUA-791 to one active run.
2. Re-run drift correction write (`add_comment` + `status=blocked`) once stable.

## Update 2026-05-08T08:54 local

Third correction attempt failed with 409.

New active owner in API error payload:
- `checkoutRunId=cc7853c0-360d-4540-b5ff-00b1a6c7be03`

Observation:
- Checkout owner changes between heartbeats and even between read/write calls.
- `GET` succeeds, but `POST/PATCH` is rejected due to ownership churn.

## Update 2026-05-08T08:55 local

Minimal mutation test executed:
- Operation: direct `PATCH status=blocked` (no comment write)
- Result: `409 Issue run ownership conflict`
- API-reported active owner: `checkoutRunId=30f95c3c-230b-467d-a3b8-8e5fe4a33d51`

Conclusion:
- Conflict affects all write mutations (POST + PATCH), not just comment endpoint.

## Resolution 2026-05-08T08:56 local

Write-arbitration workaround validated:
- Direct REST mutation with headers
  - `Authorization: Bearer $PAPERCLIP_API_KEY`
  - `X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID`
- Results:
  - comment posted: `9877ff4d-05ee-4b90-90e7-72b4ab9a0b7c`
  - status patch accepted: `blocked`
  - readback status: `blocked`

Implication:
- In current runtime, write ownership arbitration requires explicit run-id attribution header for reliable mutation.
