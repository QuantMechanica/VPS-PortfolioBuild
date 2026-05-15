# QUA-1582 Acceptance §5 Execution Receipt (2026-05-15)

Run tag: `qua1582_e2e_validset_20260515T1048Z`

## Executed
- Injected 8-job QM5_1003 P2 cohort with symbol-specific valid setfiles.
- Worker pool consumed all 8 jobs (T1/T4/T5 observed claimers).
- Transition CSV captured.
- Worker heartbeat tailed at 1-minute cadence (3 samples, 15 rows).
- Collision audit executed.
- Heartbeat-runs API window snapshot captured.

## Results
- Final status counts: `{'failed': 8}`
- Wall time: `10.0s` (`2026-05-15T10:44:33.422107Z` -> `2026-05-15T10:44:43.423342Z`)
- Gate evaluator dry-run processed done-rows: `0` (all rows ended `failed`, none `done`).
- Dominant invalidation reason: `no_summary_json:rc=1` on all 8/8.

## Acceptance mapping
- §3 worker heartbeat rows: evidence captured in `qua1582_worker_heartbeat_tail_1min.csv`.
- §4 claim collision audit: zero duplicates in `qua1582_claim_collision_audit_validset.csv`.
- §5 E2E timing + transitions: `qua1582_jobs_transitions_validset.csv` + `qua1582_e2e_timing_validset.csv`.
- §8 heartbeat-runs window: `qua1582_heartbeat_runs_window.json`.

## Blocker
`no_summary_json:rc=1` on 8/8 means MT5 execution artifact generation failed before `done` stage; gate evaluator could not roll forward. This is infra-blocking for complete §5 PASS and requires runner/runtime fix.
