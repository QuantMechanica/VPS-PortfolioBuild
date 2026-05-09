# Framework Pipeline Runners (Phase 2b)

Each runner emits deterministic JSON under `D:\QM\reports\pipeline\<ea_id>\<phase>\` and appends structured records to `phase_runner_log.jsonl`.

## One-line CLI

- `python framework/scripts/p35_csr_runner.py --ea QM5_1001 --baseline-csv framework/scripts/tests/fixtures/p35_baseline.csv --csr-results-csv framework/scripts/tests/fixtures/p35_csr.csv`
- `python framework/scripts/p4_walk_forward.py --ea QM5_1001 --walk-forward-csv framework/scripts/tests/fixtures/p4_walk_forward.csv`
- `python framework/scripts/build_vps_slippage_latency_calibration_v2.py --ea QM5_1003 --input-json artifacts/qua-228/vps_slippage_latency_calibration_v2_measured_20260427_162544.json --output-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`
- `python framework/scripts/p5_stress_runner.py --ea QM5_1001 --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --clean-metrics-json framework/scripts/tests/fixtures/p5_clean_metrics.json --stress-metrics-json framework/scripts/tests/fixtures/p5_stress_metrics.json`
- `python framework/scripts/p5_stress_runner.py --ea QM5_1001 --calibration-json framework/scripts/tests/fixtures/p5_calibration_ready.json --clean-metrics-json framework/scripts/tests/fixtures/p5_clean_metrics.json --stress-metrics-json framework/scripts/tests/fixtures/p5_stress_metrics.json --out-prefix .scratch/pipeline`
- `python framework/scripts/p5_stress_runner.py --ea QM5_1001 --calibration-json framework/scripts/tests/fixtures/p5_calibration_ready.json --clean-metrics-json framework/scripts/tests/fixtures/p5_clean_metrics.json --stress-metrics-json framework/scripts/tests/fixtures/p5_stress_metrics.json --full-history-from 2017-01-01 --full-history-to 2022-12-31 --out-prefix .scratch/pipeline`
- `python framework/scripts/p5_stress_driver.py --ea QM5_1001 --symbols EURUSD.DWX,GBPUSD.DWX,USDJPY.DWX,AUDUSD.DWX,USDCAD.DWX --year 2024 --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --base-setfile framework/EAs/QM5_1001_davey_baseline_3bar/sets/QM5_1001_EURUSD_D1_backtest.set --max-parallel 5 --out-prefix D:/QM/reports/pipeline`
- `python framework/scripts/p5b_calibrated_noise.py --ea QM5_1001 --mc-trials framework/scripts/tests/fixtures/p5b_trials.csv --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --paths 10`
- `python framework/scripts/p5b_noise_driver.py --ea QM5_1001 --symbol EURUSD.DWX --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --paths 200 --seed 42 --out-prefix D:/QM/reports/pipeline`
- `python framework/scripts/p5c_crisis_slices.py --ea QM5_1001 --slices-csv framework/scripts/tests/fixtures/p5c_slices.csv`
- `python framework/scripts/p6_multiseed.py --ea QM5_1001 --seeds-csv framework/scripts/tests/fixtures/p6_seeds.csv --seeds 42,17,99,7,2026`
- `python framework/scripts/p6_multiseed_driver.py --ea QM5_1001 --symbol EURUSD.DWX --year 2024 --base-setfile framework/EAs/QM5_1001_davey_baseline_3bar/sets/QM5_1001_EURUSD_D1_backtest.set --seeds 42,17,99,7,2026 --max-parallel 5 --out-prefix D:/QM/reports/pipeline`
- `python framework/scripts/p7_statval.py --ea QM5_1001 --sweep-pass-rows framework/scripts/tests/fixtures/p7_sweep_pass_rows.csv --multiseed-rows framework/scripts/tests/fixtures/p7_multiseed_rows.csv`
- `python framework/scripts/p8_news_impact.py --ea QM5_1001 --news-matrix framework/scripts/tests/fixtures/p8_matrix.csv --modes OFF,PAUSE,SKIP_DAY,FTMO_PAUSE,5ers_PAUSE,no_news,news_only`
- `python framework/scripts/p8_news_driver.py --ea QM5_1001 --news-matrix framework/scripts/tests/fixtures/p8_matrix.csv --calendar-csv D:/QM/data/news_calendar/news_calendar.csv --mode all`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/run_phase.ps1 -EAId QM5_1001 -Phase P8 -UseP8NewsDriver -RunnerArgs @('--news-matrix','framework/scripts/tests/fixtures/p8_matrix.csv','--calendar-csv','D:/QM/data/news_calendar/news_calendar.csv','--mode','all')`
- `powershell -Command \"$a=@('--baseline-csv','framework/scripts/tests/fixtures/p35_baseline.csv','--csr-results-csv','framework/scripts/tests/fixtures/p35_csr.csv'); & framework/scripts/run_phase.ps1 -EAId QM5_1001 -Phase P3.5 -Symbols EURUSD.DWX -RunnerArgs $a\"`
- `python framework/scripts/aggregate_phase_results.py --ea QM5_1001 --input-root D:/QM/reports/pipeline --output-root D:/QM/reports/pipeline`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/validate_phase2b.ps1 -EvidencePath docs/ops/QUA-212_PHASE2B_VALIDATION_RECEIPT.json`

## Notes

- Model 4 enforcement remains in MT5 execution harness (`run_smoke.ps1` / backtest launchers). These phase runners only evaluate phase evidence artifacts.
- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` is currently measured (`measurement_status=MEASURED`) from T1 Darwinex data (source evidence path embedded in the file). Keep this file as the canonical P5/P5b calibration input until superseded by a newer measured capture.
- `p5b_calibrated_noise.py` accepts V5 defaults from `PIPELINE_V5_SUB_GATE_SPEC.md` (`--paths`, `--seed`, `--reject-rate-floor`, `--compliance-thresholds`, `--breach-rules`) and reports floor/limit checks when optional trial columns are present.
- `deploy_ea_to_all_terminals.ps1` idempotently deploys a single `.ex5` to `T1..T5\MQL5\Experts\QM`, creates missing directories, rejects T6 scope, and verifies SHA256 convergence on every target.
- `gen_setfile.ps1` idempotently creates/updates per-symbol set files in `framework/EAs/QM5_<id>_<slug>/sets/` using `QM5_<id>_<SYMBOL>_<TF>_<ENV>.set` naming and emits `setfile_sha256`.
- `resolve_backtest_target.py` rejects start dispatch without a resolvable `job.setfile_path` using `BACKTEST_REJECTED_NO_SETFILE`.
- Use `-EaSlug` for generator input (`-Ea` conflicts with PowerShell's built-in `-ErrorAction` alias).
- Example:
  - `powershell -ExecutionPolicy Bypass -File framework/scripts/gen_setfile.ps1 -EaSlug QM5_SRC04_S03_lien_fade_double_zeros -Symbol EURUSD.DWX -TF H1 -Env backtest`

## Pipeline-Op Matrix Dispatch (36 .DWX Symbols)

Use `resolve_backtest_target.py` as the canonical scheduler entrypoint for QUA-414 matrix flow.

```powershell
# 1) Prepare 36-symbol matrix payload for one EA+phase.
@'
{
  "ea_id": "QM5_1001",
  "version": "v1",
  "phase": "P2",
  "sub_gate_config_hash": "cfg001",
  "symbols": [
    "EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","AUDUSD.DWX","USDCAD.DWX","USDCHF.DWX","NZDUSD.DWX","EURJPY.DWX","GBPJPY.DWX",
    "AUDJPY.DWX","CADJPY.DWX","CHFJPY.DWX","EURAUD.DWX","EURCAD.DWX","EURCHF.DWX","EURNZD.DWX","GBPAUD.DWX","GBPCAD.DWX",
    "GBPCHF.DWX","GBPNZD.DWX","AUDCAD.DWX","AUDCHF.DWX","AUDNZD.DWX","CADCHF.DWX","NZDCAD.DWX","NZDCHF.DWX","EURGBP.DWX",
    "XAUUSD.DWX","XAGUSD.DWX","XTIUSD.DWX","XBRUSD.DWX","WS30.DWX","NDX.DWX","GDAXI.DWX","UK100.DWX","JPN225.DWX"
  ]
}
'@ | Set-Content -Path .scratch/matrix_36.json -Encoding UTF8

# 2) Start matrix dispatch (round-robin/load-balanced across T1..T5).
python framework/scripts/resolve_backtest_target.py `
  --job-json .scratch/matrix_36.json `
  --state-json D:\QM\Reports\pipeline\dispatch_state.json `
  --event start

# 3) Complete each symbol run with verdict/evidence.
# Repeat per symbol completion payload (single-symbol job JSON), example:
python framework/scripts/resolve_backtest_target.py `
  --job-json .scratch/job_EURUSD_P2.json `
  --state-json D:\QM\Reports\pipeline\dispatch_state.json `
  --event complete `
  --verdict PASS `
  --evidence D:\QM\Reports\pipeline\QM5_1001\P2\EURUSD.DWX\report.htm `
  --pass-threshold 1 `
  --fail-phase-label P2

# 4) On phase failure path, set unblock pointer on final completion update.
python framework/scripts/resolve_backtest_target.py `
  --job-json .scratch/job_JPN225_P2.json `
  --state-json D:\QM\Reports\pipeline\dispatch_state.json `
  --event complete `
  --verdict FAIL `
  --fail-phase-label P2 `
  --pass-threshold 1 `
  --next-strategy-unblocked SRC04_S2
```

Expected matrix state path after completion:
- `dispatch_state.json -> phase_matrix_index["<ea_id>_<version>_<phase>"]`
- Fields: `matrix[]`, `phase_verdict`, `next_strategy_unblocked`
