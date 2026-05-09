# QUA-1063 Ownership Unblock Runbook (2026-05-09)

## Problem

`PaperclipClient` mutations for QUA-1063 fail with `409 Issue run ownership conflict`.

Root cause evidence:
- `docs/ops/QUA-1063_OWNERSHIP_CONFLICT_2026-05-09.json`
- static bearer source: `C:/QM/paperclip/tools/ops/.env`
- bearer `run_id`: `4f8f7b9f-8400-4a90-a659-ec388646416e` (stale)

Issue currently expects different checkout/execution run IDs.

## Immediate Fix (OWNER/local-board)

1. Use a bearer token bound to the current QUA-1063 checkout run.
2. In the same shell, override the stale `.env` token for one command:

```powershell
$env:PAPERCLIP_BEARER_TOKEN = "<fresh token for current run>"
python C:/QM/paperclip/tools/ops/apply_issue_transition_payload.py --payload C:/QM/worktrees/cto/docs/ops/QUA-1063_ISSUE_TRANSITION_PAYLOAD_2026-05-09.json
```

3. Confirm successful transition output:
- `transitioned_issue=9f8cbeb6-4267-4770-ae3f-ab2923ee8a6e status=in_review resume=true`

## Optional Hardening

- Stop relying on `tools/ops/.env` bearer for run-owned issue mutations.
- Prefer run-scoped bearer injection from the wake/execution context.
- Keep `.env` bearer only for read-only tooling or owner-controlled maintenance tasks.

## Closeout Artifacts

- Transition payload:
  - `docs/ops/QUA-1063_ISSUE_TRANSITION_PAYLOAD_2026-05-09.json`
- Ready comment:
  - `docs/ops/QUA-1063_CLOSEOUT_COMMENT_2026-05-09.md`
- Consolidated evidence:
  - `docs/ops/QUA-1063_PARALLEL_DISPATCH_EVIDENCE_2026-05-09.md`
