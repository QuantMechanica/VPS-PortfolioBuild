# QUA-791 Unblock Runbook (CTO)

## Purpose

Complete the pending Paperclip thread update for QUA-791 once API credentials are available.

## Precondition (Unblock Owner: OWNER / credential custodian)

Populate `C:/QM/paperclip/tools/ops/.env` with:
- `PAPERCLIP_BASE_URL`
- `PAPERCLIP_BEARER_TOKEN`
- `PAPERCLIP_COMPANY_ID`

## Execute

```powershell
powershell -ExecutionPolicy Bypass -File C:/QM/repo/scripts/ops/run_qua791_comment_post_with_receipt.ps1
```

## Success Criteria

1. Console prints `RECEIPT=...` and exits with code `0`.
2. Receipt file in `C:/QM/repo/docs/ops/` shows:
   - `Exit code: 0`
   - output line `OK: posted comment to QUA-791 ... comment_id=...`
3. QUA-791 issue thread contains the CTO ratification comment body from the draft artifact.

## Evidence Inputs

- Decision memo:
  - `C:/QM/repo/docs/ops/QUA-791_CTO_RATIFICATION_2026-05-08.md`
- Thread comment draft:
  - `C:/QM/repo/docs/ops/QUA-791_PAPERCLIP_COMMENT_DRAFT_2026-05-08.md`
- Posting helper:
  - `C:/QM/repo/scripts/ops/post_qua791_comment.py`
- Wrapper + receipt writer:
  - `C:/QM/repo/scripts/ops/run_qua791_comment_post_with_receipt.ps1`

## Current Blocker Snapshot

Latest receipt confirms blocked state:
- `C:/QM/repo/docs/ops/QUA-791_COMMENT_POST_RECEIPT_2026-05-08T084232+0200.md`
- blocker message: `PAPERCLIP_BEARER_TOKEN not set in env or tools/ops/.env`
