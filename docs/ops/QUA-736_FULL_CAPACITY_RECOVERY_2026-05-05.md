# QUA-736 Full Capacity Recovery (2026-05-05T17:48+02:00)

## Actions executed

1. Forced release wave-2 for 15 in-flight rows:
- backup: `D:\QM\Reports\pipeline\dispatch_state.json.bak_qua736_release_wave2_20260505T154753Z`
- ledger: `C:\QM\repo\docs\ops\QUA-736_FORCED_RELEASE_WAVE2_RESULTS_20260505T154753Z.json`

2. Re-dispatch after release wave-2:
- run dir: `D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174804`
- result: `scheduled=6`, `duplicate=30`, `no_capacity=0`

## State after action

- `QM5_1003|v1|*|P2|H1-2024` dedup rows: `36 total`
- `complete=30`, `inflight=6`
- running counters: `T1=1, T2=1, T3=2, T4=1, T5=1`
- `phase_verdict=null` (still clean, no phantom PASS carryover)

## Snapshot

- `C:\QM\repo\docs\ops\QUA-736_FULL_CAPACITY_RECOVERY_SNAPSHOT_2026-05-05T174804.json`

## Next action

Ingest completion events for the final 6 in-flight rows when artifacts land, then evaluate genuine P2 verdict from fresh row outcomes only.
