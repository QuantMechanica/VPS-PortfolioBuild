# QUA-909 heartbeat evidence (2026-05-08, integration pass)

## Action
Executed full Phase 2b validator after introducing deterministic backtest drivers for P5/P5b/P6.

## Command
`powershell -ExecutionPolicy Bypass -File framework/scripts/validate_phase2b.ps1 -EvidencePath docs/ops/QUA-909_PHASE2B_VALIDATION_RECEIPT_2026-05-08.json`

## Result
- Overall: `PASS`
- Included suites:
  - `framework.scripts.tests.test_phase_backtest_drivers`
  - `framework.scripts.tests.test_phase_runners_contract`
  - `framework.scripts.tests.test_phase_verdict_semantics`
  - `framework.scripts.tests.test_phase_runners_idempotence`
  - `framework.scripts.tests.test_phase_end_to_end_dryrun`
  - `framework.scripts.tests.test_phase_runner_log_schema`
  - `framework.scripts.tests.test_calibration_contract`

## Receipt
- `docs/ops/QUA-909_PHASE2B_VALIDATION_RECEIPT_2026-05-08.json`
