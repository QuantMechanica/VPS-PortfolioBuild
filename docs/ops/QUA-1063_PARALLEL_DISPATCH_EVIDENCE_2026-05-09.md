# QUA-1063 Parallel Dispatch Evidence (2026-05-09)

## Scope

Backtest parallelization for:
- `framework/scripts/p5_stress_driver.py`
- `framework/scripts/p6_multiseed_driver.py`
- `framework/scripts/p2_baseline.py`

Pattern target: dispatcher-style non-blocking launch (`Popen` pool / bounded parallelism) aligned with P3 doctrine.

## Implementation Commits

- `14fea72d` `feat(pipeline): parallelize p5/p6 drivers and p2 baseline dispatch`
- `d49c6711` `docs(pipeline): document parallel dispatcher drivers and max-parallel usage`
- `0d2f43ac` `feat(p2): emit parallel start timing artifact for dispatcher evidence`
- `53c8b80e` `fix(p2): allow dry-run timing evidence without registry deployment gates`

## Timing Evidence

### P5 Stress Driver

- Artifact: `.tmp/pipeline_parallel_test_cto/QM5_1001/P5/p5_parallel_timing.json`
- Config: `--max-parallel 5`
- Measured start spread: `1.993s`
- Starts captured: `10` (clean + stress)
- Terminals observed: `T1,T2,T3,T4,T5`

### P6 Multi-Seed Driver

- Artifact: `.tmp/pipeline_parallel_test_cto/QM5_1001/P6/p6_parallel_timing.json`
- Config: `--max-parallel 5`
- Measured start spread: `0.038s`
- Starts captured: `5`
- Terminals observed: `T1,T2,T3,T4,T5`

### P2 Baseline Driver

- Artifact: `.tmp/pipeline_parallel_test_cto/QM5_1002/P2/p2_parallel_timing.json`
- Config: `--dry-run --max-parallel 5 --symbols EURUSD.DWX,GBPUSD.DWX,USDJPY.DWX,AUDUSD.DWX,USDCAD.DWX`
- Measured start spread: `0.002s`
- Starts captured: `5`
- Terminal field observed in this dry-run: `any`

## Notes

- P2 dry-run in this branch records timing without MT5 launch and without registry deployment gates.
- The specific 5-symbol P2 dry-run intentionally produced `INVALID` verdict rows for missing setfiles; this does not affect launch timing evidence.
