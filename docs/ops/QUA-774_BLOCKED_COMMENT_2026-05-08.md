QUA-774 blocker refresh:
- gate.status: blocked
- verdict: FAIL
- failure_flags: REPORT_MISSING;INCOMPLETE_RUNS
- missing_terminals: T1,T2,T3,T4,T5
- missing_timeframes: H1,H4,D1
- unblock_owner: DWX source acquisition + import pipeline owner
- unblock_action: Import US500.DWX history+ticks into T1 custom symbols. | Sync US500.DWX from T1 to T2-T5 using infra/scripts/Sync-CustomSymbolData.ps1. | Re-run QM5_1004 US500 P2 redeploy and regenerate reports. | Re-run infra/scripts/Test-P2RedeploySummary.ps1 until verdict=PASS.
- evidence: QUA-774_P2_REDEPLOY_SUMMARY_20260508T063929Z.json

