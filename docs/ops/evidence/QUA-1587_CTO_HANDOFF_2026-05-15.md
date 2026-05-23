# QUA-1587 CTO handoff (2026-05-15)

Status: READY_FOR_CTO_REVIEW

## Delivered commits

1. `c09ef7841`
- `framework/scripts/run_smoke.ps1`
  - Added resilient temp path resolver for dispatch temp files (`Get-QmTempDirectory`).
- `framework/scripts/mt5_worker.py`
  - Worker passes `-AllowRunningTerminal` to `run_smoke`.
  - Worker passes explicit `-TimeoutSeconds` (CLI: `--timeout-seconds`, default 60).

2. `c2383149e`
- Added acceptance rerun transcript/evidence file.

## Evidence files

- `docs/ops/evidence/QUA-1587_no_summary_json_rc1_fix_2026-05-15.md`
- `docs/ops/evidence/QUA-1587_acceptance_rerun_done_summary_2026-05-15.md`

## Acceptance mapping

Required by board comment:
1) Root-cause `run_smoke` summary non-generation in worker context.
- Proven: empty `TEMP` caused pre-summary crash on dispatch temp file creation.
- Fixed and repro-verified.

2) Produce one rerun where at least one job reaches `status=done` with summary path.
- Proven in worker-pool path:
  - worker stdout: `{"job_id":"qua1587-proof-1","status":"done","terminal":"T5","verdict":"FAIL"}`
  - DB row includes `result_path`: `D:\QM\reports\pipeline\qua1587_done_proof\QM5_1001\20260515_111428\summary.json`

3) Attach fix evidence + command transcript.
- Attached in the two evidence files above.

## CTO verification quick checks

```powershell
# Show code changes
 git show c09ef7841 -- framework/scripts/run_smoke.ps1 framework/scripts/mt5_worker.py

# Show acceptance proof doc
 Get-Content C:\QM\repo\docs\ops\evidence\QUA-1587_acceptance_rerun_done_summary_2026-05-15.md
```
