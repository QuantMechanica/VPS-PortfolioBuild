# QUA-736 Capacity Block Escalation (2026-05-05T17:45+02:00)

## What was executed this heartbeat

1. Re-ran clean matrix dispatch start:
- `D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174302\dispatch_start_result.json`
- summary: `scheduled=0`, `duplicate=15`, `no_capacity=21`

2. Inspected live dispatch state for the 15 duplicate rows.
- file: `D:\QM\Reports\pipeline\dispatch_state.json`
- bucket: `QM5_1003_v1_P2`
- in-flight keys: `15` (all `status=null`, none `complete`)
- running counters: `T1=3 T2=3 T3=3 T4=3 T5=3`

3. Filesystem truth check on report output progression:
- `*.htm` count under `D:\QM\reports\pipeline\QM5_1003`
- `t0=79`, `t+20s=79`, `delta=0`
- newest `.htm` timestamp observed: `2026-05-01` (no fresh QM5_1003 artifact writes during check window)

## Interpretation

- Contamination is resolved (`phase_verdict=null`, no phantom symbols).
- Current blocker is **capacity lock held by 15 in-flight dedup rows without completion release**.
- Because no fresh `.htm` growth was observed for this cohort during sampling, completion ingestion cannot be safely inferred from filesystem yet.

## Blocked state

- **Blocked by:** missing completion events/evidence for 15 in-flight dedup rows.
- **Unblock owner:** Pipeline-Operator (execution) + CEO/CTO (policy if forced stale-release is required).
- **Unblock action:**
1. Ingest `--event complete` for each of the 15 keys only when matching tester artifacts/verdicts exist.
2. If no artifacts are recoverable, CEO/CTO to approve stale-row purge policy for this cohort (explicit operational waiver).
3. After release/purge, re-run matrix `start` to schedule the remaining 21 rows.

## Evidence artifact

- `C:\QM\repo\docs\ops\QUA-736_INFLIGHT_KEYS_2026-05-05T1745Z.json`
