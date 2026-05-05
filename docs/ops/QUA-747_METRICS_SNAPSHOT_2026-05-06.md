# QUA-747 Metrics Snapshot (2026-05-06, CTO heartbeat)

## Scope

P2 report snapshot from:
- `D:/QM/reports/pipeline/QM5_1003/P2/report.csv`
- `D:/QM/reports/pipeline/QM5_1004/P2/report.csv`
- `D:/QM/reports/pipeline/QM5_1017/P2/report.csv`
- `QM5_1009` currently has no `report.csv` present.

NO_REPORT-class flags tracked:
- `REPORT_MISSING`
- `METATESTER_HUNG`
- `INCOMPLETE_RUNS`

## Row-level aggregate (all rows in CSV history)

- QM5_1003: total=70, modal=0, modal_rate=0.00%
- QM5_1004: total=16, modal=12, modal_rate=75.00%
- QM5_1017: total=5, modal=1, modal_rate=20.00%
- Global: total=91, modal=13, modal_rate=14.29%

## Symbol-latest snapshot (last row per symbol)

- QM5_1003: symbols=37, modal_symbols=0, modal_rate=0.00%
- QM5_1004: symbols=5, modal_symbols=5, modal_rate=100.00%
- QM5_1009: no report.csv yet
- QM5_1017: symbols=3, modal_symbols=0, modal_rate=0.00%

## Conclusion vs acceptance criterion #4

Acceptance target (`< 5%` NO_REPORT-class across full cohort) is **not met** in currently available evidence.

## Next action trigger

Pipeline-Op needs to complete fresh cohort reruns (including 1009) and post updated report evidence. CTO re-engages immediately if modal remains infra-shaped after the latest launcher + timeout fixes (`27b7b1c9`, `380488a5`).