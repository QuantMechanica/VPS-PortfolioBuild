# QUA-747 Gate Snapshot (2026-05-06T01:00Z)

## Additional concrete execution this heartbeat

Command executed:
`python framework/scripts/p2_baseline.py --ea QM5_1004 --symbols EURUSD.DWX,GBPUSD.DWX,USDJPY.DWX,USDCAD.DWX,NZDUSD.DWX,XAUUSD.DWX,XAGUSD.DWX,EURJPY.DWX,GBPJPY.DWX,EURGBP.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120`

Result:
- 10/10 symbols completed with `FAIL run_smoke_fail:MIN_TRADES_NOT_MET`
- 0 modal rows (`REPORT_MISSING` / `METATESTER_HUNG` / `INCOMPLETE_RUNS`)

## Recomputed latest-row snapshot

- QM5_1003: symbols=37, modal=0 (0.00%)
- QM5_1004: symbols=15, modal=0 (0.00%)
- QM5_1009 (`QM5_SRC04_S03` path): symbols=6, modal=0 (0.00%)
- QM5_1017: symbols=4, modal=0 (0.00%)

Aggregate currently present:
- symbols=62
- modal=0
- modal_rate=0.00%

## Gate interpretation

Criterion #4 (`NO_REPORT-class < 5%`) remains satisfied on currently available latest-symbol evidence, now with expanded coverage versus prior 52-symbol snapshot.