# QUA-909 heartbeat evidence (2026-05-08, live samples round 2)

Timestamp: 2026-05-08T17:39:25+02:00

## Mandatory heartbeat action
- `python next_task.py --agent cto --json` executed from `C:/QM/paperclip/tools/ops`.

## Live sample executions (real EA/symbol)

EA: `QM5_1003`
Symbol: `EURUSD.DWX`
Year/Period: `2024 / H1`
Terminal: `T1`
Calibration: `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`
Base setfile: `framework/EAs/QM5_1003_davey_baseline_3bar/sets/QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set`

### P5 driver (`p5_stress_driver.py`)
Command executed:
`python framework/scripts/p5_stress_driver.py --ea QM5_1003 --symbol EURUSD.DWX --year 2024 --period H1 --terminal T1 --runs 2 --min-trades 20 --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --base-setfile framework/EAs/QM5_1003_davey_baseline_3bar/sets/QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set --out-prefix D:/QM/reports/pipeline --allow-running-terminal --smoke-timeout-seconds 2400`

Outcome:
- Driver failed because `run_smoke.ps1` returned `run_smoke.result=FAIL`.
- Reason classes: `REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`

Artifacts emitted by smoke:
- Summary: `D:/QM/reports/smoke/QM5_1003/20260508_152239/summary.json`
- Report dir: `D:/QM/reports/smoke/QM5_1003/20260508_152239`
- Evidence note: `D:/QM/reports/framework/22/20260508_152239_QM5_1003_run_smoke.md`

### P5b driver (`p5b_noise_driver.py`)
Command executed:
`python framework/scripts/p5b_noise_driver.py --ea QM5_1003 --symbol EURUSD.DWX --calibration-json framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json --paths 200 --seed 42 --out-prefix D:/QM/reports/pipeline`

Outcome:
- PASS (driver completed and wrote deterministic MC trials CSV).

Artifacts:
- `D:/QM/reports/pipeline/QM5_1003/P5b/p5b_trials.csv`

### P6 driver (`p6_multiseed_driver.py`)
Command executed:
`python framework/scripts/p6_multiseed_driver.py --ea QM5_1003 --symbol EURUSD.DWX --year 2024 --period H1 --terminal T1 --runs 2 --min-trades 20 --base-setfile framework/EAs/QM5_1003_davey_baseline_3bar/sets/QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set --seeds 42,17,99,7,2026 --out-prefix D:/QM/reports/pipeline --allow-running-terminal --smoke-timeout-seconds 2400`

Outcome:
- Driver failed on first seed because `run_smoke.ps1` returned `run_smoke.result=FAIL`.
- Reason classes: `REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`

Artifacts emitted by smoke:
- Summary: `D:/QM/reports/smoke/QM5_1003/20260508_153051/summary.json`
- Report dir: `D:/QM/reports/smoke/QM5_1003/20260508_153051`
- Evidence note: `D:/QM/reports/framework/22/20260508_153051_QM5_1003_run_smoke.md`
- Seed setfile prepared before failure: `D:/QM/reports/pipeline/QM5_1003/P6/QM5_1003_EURUSD_DWX_seed_42.set`

## Blocker + owner
- Blocker: smoke runtime verdict rejects with `MODEL4_MARKER_REQUIRED` on this terminal/session despite valid backtest invocations.
- Unblock owner: Pipeline-Op / DevOps runtime.
- Required action: remediate MT5 log/report marker path for Model 4 validation (or provide approved launcher flag contract) and then rerun P5/P6 live samples.

## Next concrete action
- After runtime unblock, rerun the same P5/P6 commands above and attach resulting `p5_clean_metrics.json`, `p5_stress_metrics.json`, and `p6_seeds.csv` paths.
