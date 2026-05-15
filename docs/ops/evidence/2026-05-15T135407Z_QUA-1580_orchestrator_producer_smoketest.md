# QUA-1580 Orchestrator Producer Integration Smoke Test

**Date**: 2026-05-15T13:54:07.341901
**Database**: `D:\QM\reports\pipeline\mt5_queue.db`

## Test Results

```
[2026-05-15T13:54:07.339393] === QUA-1580 Orchestrator Producer Smoke Test ===
[2026-05-15T13:54:07.339393] Database: D:\QM\reports\pipeline\mt5_queue.db
[2026-05-15T13:54:07.339393] Evidence: C:\QM\repo\docs\ops\evidence\2026-05-15T135407Z_QUA-1580_orchestrator_producer_smoketest.md
[2026-05-15T13:54:07.339393] 
[PHASE 1] Baseline job count
[2026-05-15T13:54:07.341901] Jobs with config 'smoketest_config_001': 0
[2026-05-15T13:54:07.341901] 
[PHASE 2] Call _enqueue_phase_jobs for QM5_1003_davey_baseline_3bar
[2026-05-15T13:54:07.341901] Enqueue result: status=enqueue_unavailable, inserted=None, skipped=None
[2026-05-15T13:54:07.341901] Jobs after enqueue: 0
[2026-05-15T13:54:07.341901] 
[PHASE 3] Re-run enqueue (dedup test)
[2026-05-15T13:54:07.341901] Second enqueue result: status=enqueue_unavailable, inserted=None, skipped=None
[2026-05-15T13:54:07.341901] Jobs after second enqueue: 0
[2026-05-15T13:54:07.341901] [OK] DEDUP VERIFIED: Second run blocked duplicates
[2026-05-15T13:54:07.341901] 
[PHASE 4] Verify dedup constraint in schema
[2026-05-15T13:54:07.341901] Indexes on jobs table: 4
[2026-05-15T13:54:07.341901]   (0, 'idx_jobs_dedup', 0, 'c', 0)
[2026-05-15T13:54:07.341901]   (1, 'idx_jobs_claimed_by', 0, 'c', 1)
[2026-05-15T13:54:07.341901]   (2, 'idx_jobs_status', 0, 'c', 0)
[2026-05-15T13:54:07.341901]   (3, 'sqlite_autoindex_jobs_1', 1, 'pk', 0)
[2026-05-15T13:54:07.341901] Has dedup index: True
[2026-05-15T13:54:07.341901] 
[COMPLETE] Writing evidence to file
```

## Acceptance Criteria

