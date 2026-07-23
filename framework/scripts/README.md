# Framework Pipeline Runners (Phase 2b)

Each runner emits deterministic JSON under `D:\QM\reports\pipeline\<ea_id>\<phase>\` and appends structured records to `phase_runner_log.jsonl`.

## One-line CLI

- `python framework/scripts/p35_csr_runner.py --ea QM5_1001 --baseline-csv framework/scripts/tests/fixtures/p35_baseline.csv --csr-results-csv framework/scripts/tests/fixtures/p35_csr.csv`
- `python framework/scripts/p5_stress_runner.py --ea QM5_1001 --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --clean-metrics-json framework/scripts/tests/fixtures/p5_clean_metrics.json --stress-metrics-json framework/scripts/tests/fixtures/p5_stress_metrics.json`
- `python framework/scripts/p5_stress_runner.py --ea QM5_1001 --calibration-json framework/scripts/tests/fixtures/p5_calibration_ready.json --clean-metrics-json framework/scripts/tests/fixtures/p5_clean_metrics.json --stress-metrics-json framework/scripts/tests/fixtures/p5_stress_metrics.json --out-prefix .scratch/pipeline`
- `python framework/scripts/p5_stress_runner.py --ea QM5_1001 --calibration-json framework/scripts/tests/fixtures/p5_calibration_ready.json --clean-metrics-json framework/scripts/tests/fixtures/p5_clean_metrics.json --stress-metrics-json framework/scripts/tests/fixtures/p5_stress_metrics.json --full-history-from 2017-01-01 --full-history-to 2022-12-31 --out-prefix .scratch/pipeline`
- `python framework/scripts/p5b_calibrated_noise.py --ea QM5_1001 --mc-trials framework/scripts/tests/fixtures/p5b_trials.csv --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --paths 10`
- `python framework/scripts/p5c_crisis_slices.py --ea QM5_1001 --slices-csv framework/scripts/tests/fixtures/p5c_slices.csv`
- `python framework/scripts/p6_multiseed.py --ea QM5_1001 --seeds-csv framework/scripts/tests/fixtures/p6_seeds.csv --seeds 42,17,99,7,2026`
- `python framework/scripts/p7_statval.py --ea QM5_1001 --sweep-pass-rows framework/scripts/tests/fixtures/p7_sweep_pass_rows.csv --multiseed-rows framework/scripts/tests/fixtures/p7_multiseed_rows.csv`
- `python framework/scripts/p8_news_impact.py --ea QM5_1001 --news-matrix framework/scripts/tests/fixtures/p8_matrix.csv --modes OFF,PAUSE,SKIP_DAY,FTMO_PAUSE,5ers_PAUSE,no_news,news_only`
- `powershell -Command \"$a=@('--baseline-csv','framework/scripts/tests/fixtures/p35_baseline.csv','--csr-results-csv','framework/scripts/tests/fixtures/p35_csr.csv'); & framework/scripts/run_phase.ps1 -EAId QM5_1001 -Phase P3.5 -Symbols EURUSD.DWX -RunnerArgs $a\"`

## Multi-EA Scheduler

- Build queue from source payload:
  - `python framework/scripts/build_multi_ea_queue.py --source D:/QM/Reports/pipeline/multi_ea_queue_source.json --out D:/QM/Reports/pipeline/multi_ea_job_queue.json`
- Run saturator once:
  - `python framework/scripts/multi_ea_scheduler.py --once --queue-source D:/QM/Reports/pipeline/multi_ea_queue_source.json`
- `multi_ea_queue_source.json` schema:
  - `approved_waiting_p0`: array of `{ea_id, phase, symbol, config_hash}`
  - `transition_ready`: array of `{ea_id, phase, symbol, config_hash}`
- Build transition-ready feed from phase results:
  - `python framework/scripts/next_phase_job_decider.py --phase-results D:/QM/Reports/pipeline/phase_results_latest.json --out D:/QM/Reports/pipeline/multi_ea_transition_ready.json`
- Evaluate saturation gate (default: >=50% avg active over 5 minutes):
  - `python framework/scripts/measure_mt5_saturation.py --state D:/QM/Reports/pipeline/multi_ea_scheduler_state.json --min-ratio 0.5 --min-minutes 5`
- Timed saturation monitor (supports real 5+ minute trial):
  - `python framework/scripts/monitor_saturation_window.py --state D:/QM/Reports/pipeline/multi_ea_scheduler_state.json --duration-minutes 5 --min-ratio 0.5`
  - Add `--no-wait` to evaluate the trailing window immediately.
- `python framework/scripts/aggregate_phase_results.py --ea QM5_1001 --input-root D:/QM/reports/pipeline --output-root D:/QM/reports/pipeline`

## Notes

- Model 4 enforcement remains in MT5 execution harness (`run_smoke.ps1` / backtest launchers). These phase runners only evaluate phase evidence artifacts.
- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` is intentionally scaffolded as `PENDING_MEASUREMENT`; Pipeline-Operator must replace it with measured T1 Darwinex data before production P5/P5b decisions.
- `p5b_calibrated_noise.py` accepts V5 defaults from `PIPELINE_V5_SUB_GATE_SPEC.md` (`--paths`, `--seed`, `--reject-rate-floor`, `--compliance-thresholds`, `--breach-rules`) and reports floor/limit checks when optional trial columns are present.

## Dispatcher-Pattern Backtest Drivers

- `python framework/scripts/p5_stress_driver.py --ea QM5_1001 --symbol EURUSD.DWX --symbols EURUSD.DWX,GBPUSD.DWX,USDJPY.DWX,AUDUSD.DWX,USDCAD.DWX --year 2024 --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --max-parallel 5 --out-prefix D:/QM/reports/pipeline`
- `python framework/scripts/p6_multiseed_driver.py --ea QM5_1001 --symbol EURUSD.DWX --year 2024 --seeds 42,17,99,7,2026 --max-parallel 5 --out-prefix D:/QM/reports/pipeline`
- `python framework/scripts/p2_baseline.py --ea QM5_1001 --year 2024 --max-parallel 5`

Behavior:
- `p5_stress_driver.py` and `p6_multiseed_driver.py` use a `subprocess.Popen` pool and emit `p5_parallel_timing.json` / `p6_parallel_timing.json`.
- Default terminal is `any`, which distributes jobs round-robin across `T1..T5`; pinning remains possible via `--terminal T1` (or `T2..T5`).
- `p2_baseline.py` runs symbols concurrently with `ThreadPoolExecutor` when no terminal pin is provided.
