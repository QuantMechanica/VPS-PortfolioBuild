# QUA-774 External Unblock Escalation (2026-05-08)

Issue remains blocked: blocked
Failure flags: REPORT_MISSING;INCOMPLETE_RUNS

Unblock owner: DWX source acquisition + import pipeline owner

Required unblock actions:
1. Import US500.DWX history+ticks into T1 custom symbols.
2. Sync US500.DWX from T1 to T2-T5 using infra/scripts/Sync-CustomSymbolData.ps1.
3. Re-run QM5_1004 US500 P2 redeploy and regenerate reports.
4. Re-run infra/scripts/Test-P2RedeploySummary.ps1 until verdict=PASS.

Child issue payload artifact:
- docs\ops\QUA-774_EXTERNAL_UNBLOCK_CHILD_PAYLOAD_2026-05-08.json

Resume contract:
- Update `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json` to `ready_to_resume=true` only after all external acceptance criteria are met.
