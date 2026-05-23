# QUA-1582 Continuation Evidence + Blocker Receipt (2026-05-15)

## Completed this heartbeat

1. Collision audit (acceptance §4 equivalent on current schema)
   - Query result: zero duplicates
   - Evidence: `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_collision_audit.csv`

2. State transition CSV (queue lifecycle in current adapter)
   - Exported transition rows for cohort hash `cfg_qua1582_e2e_20260515T1215Z`
   - Evidence: `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_state_transition_log.csv`

3. Schema and scheduler reality check
   - DB tables present: `mt5_job_queue`, `sqlite_sequence`
   - `jobs` + `worker_heartbeat` tables are not present in active DB.
   - `QM_MT5_Worker_T1..T5` and `QM_GateEvaluator_5min` scheduled tasks are not present.

## Blockers against parent acceptance surface

A. Acceptance §3 (`worker_heartbeat` 5 rows within 90s)
- Blocked because worker-heartbeat table does not exist in active queue schema.
- Unblock owner: CTO + Dev-Codex (schema/worker-loop rollout)
- Required action: deploy `jobs` + `worker_heartbeat` schema and worker tasks, then rerun sampling capture.

B. Acceptance §5 full E2E (`queued -> claimed/running -> done` + gate evaluator)
- Current adapter proves `queued -> dispatched` scheduling, but not worker claim/run/done transitions in this DB.
- Unblock owner: CTO + Dev-Codex + HoP integration
- Required action: enable worker loop + gate evaluator path and rerun smoke window.

C. Acceptance §8 (`GET /heartbeat-runs?limit=200` token-window proof)
- Blocked in this shell: `PAPERCLIP_API_URL` and `PAPERCLIP_API_KEY` not injected (`MISSING_ENV`).
- Unblock owner: Harness/runtime injection owner (Paperclip runtime)
- Required action: rerun heartbeat in injected runtime context or provide API token via harness.

## Files produced in this continuation
- `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_collision_audit.csv`
- `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_state_transition_log.csv`
- `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/qua1582_continuation_blocker_receipt_2026-05-15.md`
