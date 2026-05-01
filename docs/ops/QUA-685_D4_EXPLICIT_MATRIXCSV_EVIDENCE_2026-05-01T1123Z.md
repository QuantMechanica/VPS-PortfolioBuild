# QUA-685 D4 — Explicit `--matrix-csv` Execution Evidence (2026-05-01T11:23Z)

Executed exactly with explicit matrix-csv input:

- `python infra/scripts/build_p2_dispatch_matrix.py --matrix-csv framework/registry/dwx_symbol_matrix.csv --out-json .scratch/qua685_p2_matrix_dispatch_explicit_matrix_csv_2026-05-01.json --ea-id QM5_1003 --version v1 --phase P2 --sub-gate-config-hash H1-2024`
- `python framework/scripts/resolve_backtest_target.py --event start --job .scratch/qua685_p2_matrix_dispatch_explicit_matrix_csv_2026-05-01.json --state .scratch/qua685_dispatch_state_explicit_matrix_csv_test.json --dedup-index .scratch/qua685_dedup_index_explicit_matrix_csv_test.json`

Results:
- `matrix_count=36`
- `scheduled=15`
- `no_capacity=21`
- `duplicate=0`

Raw command output log:
- `docs/ops/QUA-685_D4_EXPLICIT_MATRIXCSV_RUN_2026-05-01T1123Z.log`
