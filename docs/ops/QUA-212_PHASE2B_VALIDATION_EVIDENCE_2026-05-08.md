# QUA-212 Phase 2b Validation Evidence (2026-05-08)

## Scope
Phase 2b pipeline runner layer for `P3.5/P5/P5b/P5c/P6/P7/P8` plus calibration JSON contract.

## Implemented runner contract alignment
- `framework/scripts/p5_stress_runner.py`
- `framework/scripts/p6_multiseed.py`
- `framework/scripts/p7_statval.py`

These now emit canonical phase artifacts under:
- `<out>/<ea>/<phase_token>/<phase_token>_<ea>_result.json`
- `<out>/<ea>/<phase_token>/phase_runner_log.jsonl`

## Fixture set added
- `framework/scripts/tests/fixtures/p35_baseline.csv`
- `framework/scripts/tests/fixtures/p35_csr.csv`
- `framework/scripts/tests/fixtures/p5_clean_metrics.json`
- `framework/scripts/tests/fixtures/p5_stress_metrics.json`
- `framework/scripts/tests/fixtures/p5_calibration_ready.json`
- `framework/scripts/tests/fixtures/p5b_trials.csv`
- `framework/scripts/tests/fixtures/p5c_slices.csv`
- `framework/scripts/tests/fixtures/p6_seeds.csv`
- `framework/scripts/tests/fixtures/p7_sweep_pass_rows.csv`
- `framework/scripts/tests/fixtures/p7_multiseed_rows.csv`
- `framework/scripts/tests/fixtures/p8_matrix.csv`

## Tests added
- `framework/scripts/tests/test_phase_runners_contract.py`
- `framework/scripts/tests/test_phase_runners_idempotence.py`
- `framework/scripts/tests/test_phase_end_to_end_dryrun.py`
- `framework/scripts/tests/test_phase_runner_log_schema.py`
- `framework/scripts/tests/test_calibration_contract.py`

## Verification receipts
Executed and passing:
1. `python -m unittest framework/scripts/tests/test_phase_runners_contract.py`
2. `python -m unittest framework/scripts/tests/test_phase_runners_idempotence.py`
3. `python -m unittest framework/scripts/tests/test_phase_end_to_end_dryrun.py`
4. `python -m unittest framework/scripts/tests/test_phase_runner_log_schema.py`
5. `python -m unittest framework/scripts/tests/test_calibration_contract.py`

## End-to-end handoff proof
`test_phase_end_to_end_dryrun.py` proves:
- `run_phase.ps1 -> <phase runner> -> aggregate_phase_results.py -> index.json`
- Aggregate output assertions:
  - `ea_id = QM5_1001`
  - `final_verdict = READY`
  - `phase_blockers = []`

## Calibration status lock
- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` is `measurement_status=MEASURED`.
- `framework/scripts/README.md` note updated to reflect measured canonical status.

## Notes
Kanban binding command continues to return no actionable CTO row:
- `python next_task.py --agent cto --json` -> `{"tasks":[],"message":"no actionable tasks"}`

## Validator replay + machine receipt
Single-command replay:
- `powershell -ExecutionPolicy Bypass -File framework/scripts/validate_phase2b.ps1 -EvidencePath docs/ops/QUA-212_PHASE2B_VALIDATION_RECEIPT.json`

Machine-readable receipt artifact:
- `docs/ops/QUA-212_PHASE2B_VALIDATION_RECEIPT.json`

## Dispatch blocker artifact
- `docs/ops/QUA-212_KANBAN_DISPATCH_GAP_2026-05-08.md`
