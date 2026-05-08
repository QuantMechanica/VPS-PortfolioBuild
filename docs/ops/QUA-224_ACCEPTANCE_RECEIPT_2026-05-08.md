# QUA-224 Acceptance Receipt (2026-05-08)

Issue: QUA-224  
Phase: P5 calibration source (Phase 2b child of QUA-212)

## Deliverable

- Calibration JSON path: `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`
- Source measured evidence: `artifacts/qua-228/vps_slippage_latency_calibration_v2_measured_20260427_162544.json`

## Acceptance Checklist

- [x] Script compiles / runs without error on a test fixture
  - `python -m unittest framework.tests.unit.test_build_vps_slippage_latency_calibration_v2`
  - Result: `OK` (2 tests)
- [x] Output schema matches `PIPELINE_V5_SUB_GATE_SPEC.md` §P5 table
  - Contains per-symbol `slippage_points avg/p95`, `commission_cents_per_lot`, `latency_ms avg/p95`, `spread_points median/p95`
- [x] Idempotent output for identical inputs
  - SHA256 run1: `F7C25EDA189E6BA95434704D4B68F008854B2510734CFF020640F92EA39E2C71`
  - SHA256 run2: `F7C25EDA189E6BA95434704D4B68F008854B2510734CFF020640F92EA39E2C71`
  - Equality: `true`
- [x] Structured JSON logging with required fields
  - Log path: `framework/calibrations/evidence/phase_runner_log.jsonl`
  - Fields emitted: `phase`, `ea_id`, `verdict`, `criterion`, `evidence_path`
- [x] One-line CLI documented
  - `framework/scripts/README.md`
- [x] Unit-test fixture with happy path + edge case
  - `framework/tests/unit/test_build_vps_slippage_latency_calibration_v2.py`

## Implemented Files

- `framework/scripts/build_vps_slippage_latency_calibration_v2.py`
- `framework/tests/unit/test_build_vps_slippage_latency_calibration_v2.py`
- `framework/scripts/README.md`
- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`

## Repro Command

```powershell
python framework/scripts/build_vps_slippage_latency_calibration_v2.py --ea QM5_1003 --input-json artifacts/qua-228/vps_slippage_latency_calibration_v2_measured_20260427_162544.json --output-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --log-jsonl framework/calibrations/evidence/phase_runner_log.jsonl
```

## Status Recommendation

QUA-224 is implementation-complete on the repository side and ready for issue transition to `done` with this receipt + file paths as evidence.
