# QUA-1582 E2E Smoke Evidence (acceptance §5)

UTC: 2026-05-15

## Scope executed
- Enqueued 8 jobs for `ea_id=QM5_1003`, `phase=P2`, hash `cfg_qua1582_e2e_20260515T1215Z`.
- Ran saturation scheduler ticks against `D:/QM/reports/pipeline/mt5_queue.db` + `D:/QM/Reports/pipeline/dispatch_state.json`.
- Exported CSV of per-job state transitions.

## Command evidence
- enqueue: inserted IDs `2..9`
- tick1 evidence: `qua1582_tick1_evidence.json`
- tick2 summary: `scheduled=3`, `queued_scanned=3`, `available_slots_after=2`

## Result snapshot
- Cohort row count: `8`
- Status counts: `dispatched=8`
- Terminal distribution: T1=2, T2=2, T3=2, T4=1, T5=1

## Artifacts
- `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_e2e_job_transitions.csv`
- `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_e2e_summary.json`
- `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_tick1_evidence.json`

## Notes
- This heartbeat verified producer+scheduler dispatch transitions (queue -> dispatched) for 8-symbol smoke cohort.
- Worker-run MT5 execution (`done` rows with summary artifacts) is outside this exact run because current queue adapter marks dispatch ownership and relies on downstream runner path.
