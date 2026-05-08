# QUA-909 Phase Coverage Audit (P5/P5b/P6 Drivers)

Date: 2026-05-08  
Owner: CTO

## Scope

Deterministic backtest drivers now exist for:
- `P5` via `framework/scripts/p5_stress_driver.py`
- `P5b` via `framework/scripts/p5b_noise_driver.py`
- `P6` via `framework/scripts/p6_multiseed_driver.py`

These emit artifacts consumed directly by existing verdict classifiers:
- `p5_stress_runner.py` (`--clean-metrics-json`, `--stress-metrics-json`)
- `p5b_calibrated_noise.py` (`--trials-csv`)
- `p6_multiseed.py` (`--seeds-csv`)

## Exact Commands

### 1) P5 driver -> classifier

```powershell
python framework/scripts/p5_stress_driver.py `
  --ea QM5_1001 `
  --symbol EURUSD.DWX `
  --year 2024 `
  --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json `
  --base-setfile framework/EAs/QM5_1001_davey_baseline_3bar/sets/QM5_1001_EURUSD_D1_backtest.set `
  --out-prefix D:/QM/reports/pipeline

python framework/scripts/p5_stress_runner.py `
  --ea QM5_1001 `
  --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json `
  --clean-metrics-json D:/QM/reports/pipeline/QM5_1001/P5/p5_clean_metrics.json `
  --stress-metrics-json D:/QM/reports/pipeline/QM5_1001/P5/p5_stress_metrics.json
```

### 2) P5b driver -> classifier

```powershell
python framework/scripts/p5b_noise_driver.py `
  --ea QM5_1001 `
  --symbol EURUSD.DWX `
  --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json `
  --paths 200 `
  --seed 42 `
  --out-prefix D:/QM/reports/pipeline

python framework/scripts/p5b_calibrated_noise.py `
  --ea QM5_1001 `
  --trials-csv D:/QM/reports/pipeline/QM5_1001/P5b/p5b_trials.csv `
  --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json `
  --symbol EURUSD.DWX `
  --paths 200 `
  --seed 42
```

### 3) P6 driver -> classifier

```powershell
python framework/scripts/p6_multiseed_driver.py `
  --ea QM5_1001 `
  --symbol EURUSD.DWX `
  --year 2024 `
  --base-setfile framework/EAs/QM5_1001_davey_baseline_3bar/sets/QM5_1001_EURUSD_D1_backtest.set `
  --seeds 42,17,99,7,2026 `
  --out-prefix D:/QM/reports/pipeline

python framework/scripts/p6_multiseed.py `
  --ea QM5_1001 `
  --seeds-csv D:/QM/reports/pipeline/QM5_1001/P6/p6_seeds.csv `
  --seeds 42,17,99,7,2026
```

## Validation Command

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/validate_phase2b.ps1
```
