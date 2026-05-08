# QUA-736 Liveness Execution Proof (2026-05-05T17:43:02+02:00)

Executed the required clean P2 matrix `start` rerun and captured post-run state snapshot.

## Run

- run dir: `D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174302`
- result json: `D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174302\dispatch_start_result.json`
- summary: `scheduled=0`, `duplicate=15`, `no_capacity=21`

## Post-run bucket state (`QM5_1003_v1_P2`)

- `rows=36`
- `none_verdict_rows=36`
- `pass_rows=0`
- `phase_verdict=null`
- phantom markers absent: `GDAXI.DWX=false`, `NDX.DWX=false`
- canonical markers present: `GDAXIm.DWX=true`, `NDXm.DWX=true`
- running load: `T1=3, T2=3, T3=3, T4=3, T5=3`

## Machine-readable snapshot

- `C:\QM\repo\docs\ops\QUA-736_LIVENESS_SNAPSHOT_2026-05-05T174302.json`

## Next action

Pipeline capacity is fully occupied. Ingest completion/release events for the 15 duplicate/in-flight rows, then rerun matrix `start` to schedule the remaining 21 currently `no_capacity` rows.
