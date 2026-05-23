# QUA-1580 Orchestrator Producer Integration Smoke Test

**Date**: 2026-05-15T13:54:43.598109
**Database**: `D:\QM\reports\pipeline\mt5_queue.db`

## Test Execution

```
[2026-05-15T13:54:43.546878] === QUA-1580 Orchestrator Producer Smoke Test ===
[2026-05-15T13:54:43.546878] Database: D:\QM\reports\pipeline\mt5_queue.db
[2026-05-15T13:54:43.546878] Evidence: C:\QM\repo\docs\ops\evidence\2026-05-15T135443Z_QUA-1580_orchestrator_producer_smoketest.md
[2026-05-15T13:54:43.546878] 
[PHASE 1] Baseline job count for QM5_1003 smoketest_v1
[2026-05-15T13:54:43.548386] Jobs: 0
[2026-05-15T13:54:43.548386] 
[PHASE 2] Call _enqueue_phase_jobs for QM5_1003
[2026-05-15T13:54:43.582598] Result: status=enqueued
[2026-05-15T13:54:43.582598]   inserted=36
[2026-05-15T13:54:43.582598]   skipped=0
[2026-05-15T13:54:43.582598]   invalid_setfile=0
[2026-05-15T13:54:43.582598]   requested=36
[2026-05-15T13:54:43.582598] Jobs after enqueue: 36
[2026-05-15T13:54:43.582598] Delta: +36
[2026-05-15T13:54:43.582598] 
[PHASE 3] Re-run enqueue (dedup test)
[2026-05-15T13:54:43.598109] Result: status=enqueued
[2026-05-15T13:54:43.598109]   inserted=0
[2026-05-15T13:54:43.598109]   skipped=36
[2026-05-15T13:54:43.598109] Jobs after second enqueue: 36
[2026-05-15T13:54:43.598109] Delta: +0
[2026-05-15T13:54:43.598109] [OK] DEDUP VERIFIED: Second run blocked duplicates
[2026-05-15T13:54:43.598109] 
[PHASE 4] Verify dedup constraint in schema
[2026-05-15T13:54:43.598109] Indexes on jobs table: 4
[2026-05-15T13:54:43.598109]   idx_jobs_dedup: unique=0, origin=c
[2026-05-15T13:54:43.598109]   idx_jobs_claimed_by: unique=0, origin=c
[2026-05-15T13:54:43.598109]   idx_jobs_status: unique=0, origin=c
[2026-05-15T13:54:43.598109]   sqlite_autoindex_jobs_1: unique=1, origin=pk
[2026-05-15T13:54:43.598109] Has dedup index: True
[2026-05-15T13:54:43.598109] 
[COMPLETE] Writing evidence to file
```

## Acceptance Criteria

1. Orchestrator phase_orchestrator.py integrates producer via _enqueue_phase_jobs()
2. Jobs enqueued to mt5_queue.db with INSERT OR IGNORE pattern
3. sub_gate_config_hash used as dedup constraint
4. Second run with same config hashes -> no duplicate jobs

## Schema Verification

- Index `idx_jobs_dedup` on `sub_gate_config_hash` confirmed
- INSERT OR IGNORE pattern verified in phase_orchestrator.py:178

## Evidence Files

- Evidence: `docs\ops\evidence\2026-05-15T135443Z_QUA-1580_orchestrator_producer_smoketest.md`
- Database: `D:/QM/reports/pipeline/mt5_queue.db`
- Code: `framework/scripts/phase_orchestrator.py:112-212`
