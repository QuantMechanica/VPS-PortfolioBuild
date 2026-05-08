# QUA-736 Capacity Recovery Execution (2026-05-05T17:46+02:00)

## Concrete actions executed

1. Forced release of 15 stale in-flight dedup rows (`QM5_1003|v1|*|P2|H1-2024`) via canonical resolver complete events.
   - backup: `D:\QM\Reports\pipeline\dispatch_state.json.bak_qua736_release_20260505T154634Z`
   - result ledger: `C:\QM\repo\docs\ops\QUA-736_FORCED_RELEASE_RESULTS_20260505T154634Z.json`

2. Immediate clean matrix re-dispatch:
   - run dir: `D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174650`
   - result file: `D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174650\dispatch_start_result.json`
   - summary: `scheduled=15`, `duplicate=15`, `no_capacity=6`

## Outcome

- Capacity was successfully recovered for this cohort.
- Remaining unscheduled symbols reduced from `21` to `6`.
- Contamination remains cleared:
  - bucket `QM5_1003_v1_P2`
  - `rows=36`, `pass_rows=0`, `phase_verdict=null`

## Snapshot

- `C:\QM\repo\docs\ops\QUA-736_CAPACITY_RECOVERY_SNAPSHOT_2026-05-05T174650.json`

## Next action

Wait for completion evidence for the 15 newly scheduled rows, ingest `--event complete`, then run one more `start` to schedule the final 6 no-capacity rows.
