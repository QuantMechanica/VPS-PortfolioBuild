## Status

Implementation complete for dispatcher-style parallelization of `P5_stress`, `P6_multiseed`, and `P2_baseline` in this branch.

## Delivered

- `framework/scripts/p5_stress_driver.py`
  - `subprocess.Popen` pool
  - `--max-parallel` (default `5`)
  - multi-symbol mode (`--symbols`)
  - default terminal routing `--terminal any` => round-robin `T1..T5`
  - timing artifact: `p5_parallel_timing.json`

- `framework/scripts/p6_multiseed_driver.py`
  - parallel seed execution via `subprocess.Popen`
  - `--max-parallel` (default `5`)
  - default terminal routing `--terminal any` => round-robin `T1..T5`
  - timing artifact: `p6_parallel_timing.json`

- `framework/scripts/p2_baseline.py`
  - parallel symbol execution via `ThreadPoolExecutor`
  - `--max-parallel` (default `5`)
  - timing artifact: `p2_parallel_timing.json`
  - dry-run mode no longer enforces registry/deployment preflight gates (timing evidence path only; no MT5 launch)

- Docs updated:
  - `framework/scripts/README.md`
  - consolidated evidence: `docs/ops/QUA-1063_PARALLEL_DISPATCH_EVIDENCE_2026-05-09.md`

## Evidence

- P5 timing spread: `1.993s` (`10` starts, clean+stress), terminals `T1..T5`
  - `.tmp/pipeline_parallel_test_cto/QM5_1001/P5/p5_parallel_timing.json`
- P6 timing spread: `0.038s` (`5` starts), terminals `T1..T5`
  - `.tmp/pipeline_parallel_test_cto/QM5_1001/P6/p6_parallel_timing.json`
- P2 timing spread: `0.002s` (`5` starts, dry-run)
  - `.tmp/pipeline_parallel_test_cto/QM5_1002/P2/p2_parallel_timing.json`

## Commits

- `14fea72d` feat(pipeline): parallelize p5/p6 drivers and p2 baseline dispatch
- `d49c6711` docs(pipeline): document parallel dispatcher drivers and max-parallel usage
- `0d2f43ac` feat(p2): emit parallel start timing artifact for dispatcher evidence
- `53c8b80e` fix(p2): allow dry-run timing evidence without registry deployment gates
- `c48778eb` docs(qua-1063): add consolidated parallel dispatch timing evidence

## Note

P2 dry-run used synthetic symbol list and produced `INVALID` rows for missing setfiles; this does not affect the measured launch spread evidence.
