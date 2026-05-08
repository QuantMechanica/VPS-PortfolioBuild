# QUA-774 Automation Index (2026-05-08)

Issue: `QUA-774`  
Status: `blocked (external)`  
Gate: `REPORT_MISSING;INCOMPLETE_RUNS` on `QM5_1004 / US500.DWX / H1,H4,D1`

## Primary unblock signal

- file: `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json`
- resume condition: `ready_to_resume=true`

## One-command blocked refresh

- `infra/scripts/Run-QUA774ExternalBlockedRefresh.ps1`
  - writes/validates current blocked automation state in one run

## Core command set

1. `infra/scripts/Write-QUA774ExternalUnblockStatusSnapshot.ps1`
2. `infra/scripts/Test-QUA774ExternalUnblockPackage.ps1`
3. `infra/scripts/Test-QUA774ExternalUnblockSignal.ps1`
4. `infra/scripts/Test-QUA774ExternalUnblockHandoffCache.ps1`
5. `infra/scripts/Test-QUA774ExternalUnblockStatusTask.ps1`
6. `infra/scripts/Test-QUA774ExternalUnblockOpsSuite.ps1`

## Scheduled tasks

1. `QM_QUA774_BlockedHeartbeat_60min`
   - launcher: `C:\QM\tasks\run_qua774_blocked_heartbeat.ps1`
2. `QM_QUA774_ExternalUnblockStatus_60min`
   - launcher: `C:\QM\tasks\run_qua774_external_unblock_status.ps1`
3. `QM_QUA774_ExternalUnblockOpsSuite_60min`
   - launcher: `C:\QM\tasks\run_qua774_external_unblock_ops_suite.ps1`

## Key artifacts

1. `docs/ops/QUA-774_EXTERNAL_UNBLOCK_STATUS_2026-05-08.json`
2. `docs/ops/QUA-774_EXTERNAL_UNBLOCK_CHILD_PAYLOAD_2026-05-08.json`
3. `docs/ops/QUA-774_EXTERNAL_UNBLOCK_ESCALATION_2026-05-08.md`
4. `docs/ops/QUA-774_EXTERNAL_UNBLOCK_HANDOFF_INDEX_2026-05-08.md`
5. `docs/ops/QUA-774_EXTERNAL_UNBLOCK_STATUS_TASK_SMOKE_2026-05-08.md`
6. `docs/ops/QUA-774_EXTERNAL_UNBLOCK_OPS_SUITE_TASK_SMOKE_2026-05-08.md`

## External unblock owner/action (unchanged)

1. Import/sync `US500.DWX` on `T1..T5`
2. Rerun `QM5_1004` P2 and provide `H1/H4/D1` reports
3. Set `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json` to `ready_to_resume=true`
