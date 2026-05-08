# QUA-793 Done Transition Receipt

- issue: `QUA-793`
- issue_id: `8dda9f96-2283-44d0-b335-b72a605fba28`
- run_id: `29d859e3-0504-4a82-b3ef-68de6e7e0c44`
- transition_time_utc: `2026-05-08T07:13:44.360Z`
- comment_id: `5deb7993-5e05-4c1b-b680-146f2bfba331`

## API actions performed

1. `POST /api/issues/{issueId}/comments`
   - body references:
     - `C:/QM/repo/docs/ops/QUA-793_CLOSEOUT_READY_2026-05-08.md`
     - `C:/QM/repo/docs/ops/QUA-793_worker_recovery_evidence_2026-05-08.md`
2. `PATCH /api/issues/{issueId}` with `{"status":"done"}`
3. `GET /api/issues/{issueId}` verification
   - confirmed `status = done`

## Notes

- Runtime API call path used with `X-Paperclip-Run-Id` context from environment.

## Drift correction (status-only, no comment)

- At `2026-05-08T07:15:16.184Z`, issue drifted back to `in_progress` due follow-up wake processing.
- Applied a status-only PATCH:
  - `PATCH /api/issues/{issueId}` with `{"status":"done"}`
- Result:
  - `identifier = QUA-793`
  - `status = done`
  - `updatedAt = 2026-05-08T07:15:16.184Z`
