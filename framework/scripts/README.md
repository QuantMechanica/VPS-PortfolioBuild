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

## MT5 Multi-EA Saturation Scheduler (SQLite queue adapter)

Deterministic one-tick scheduler that reads `mt5_job_queue` rows with `status='queued'` and dispatches into available T1-T5 capacity via `resolve_target_terminal` / `dispatch_state.json`.

```powershell
python framework/scripts/mt5_saturation_scheduler.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --dispatch-state D:\QM\Reports\pipeline\dispatch_state.json `
  --max-per-terminal 3 `
  --scan-limit 500
```

Dry-run mode (no DB/state writes):

```powershell
python framework/scripts/mt5_saturation_scheduler.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --dispatch-state D:\QM\Reports\pipeline\dispatch_state.json `
  --dry-run
```

Queue rows scheduled successfully are marked `status='dispatched'` with `assigned_terminal`, `dispatch_decision`, and `dedup_key`.

## MT5 Worker-Pool Queue Init (jobs + heartbeat schema)

Create/update the worker-pool queue schema idempotently:

```powershell
python framework/scripts/queue_init.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db
```

Expected output:
- JSON summary with `status=ok` and `sqlite=<path>`.

## MT5 Single Worker Prototype (claim-based)

Run one deterministic claim/execute cycle on a specific terminal:

```powershell
python framework/scripts/mt5_worker.py `
  --terminal T1 `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --once
```

Notes:
- `--terminal` accepts `T1..T5` only (`T6` is rejected with exit code `2`).
- Worker updates `worker_heartbeat`, claims the next `jobs.status='queued'` row atomically, then marks `done`/`failed`.

## MT5 Queue Status Snapshot (worker heartbeat surface)

Read a compact status snapshot from `mt5_queue.db`:

```powershell
python framework/scripts/mt5_queue_status.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --limit 5
```

Expected output keys:
- `schema`: `worker_pool` (canonical `jobs + worker_heartbeat`) or `legacy_saturation` (`mt5_job_queue` fallback).
- `counts`: grouped job counts by `status`.
- `queued_top`: top queued rows.
- `dispatched_top`: active claimed/running rows (worker schema) or dispatched rows (legacy schema).
- `worker_heartbeat_top`: latest worker heartbeats (`terminal_id`, `last_seen_utc`, `current_job_id`, `jobs_completed`, `last_error`) when worker schema is present.

## Enqueue MT5 Queue Rows (deterministic producer helper)

Use this when `mt5_queue.db` has no queued rows and you need to drive a scheduler tick without manual SQL.

```powershell
python framework/scripts/mt5_queue_enqueue.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --job-json C:\QM\repo\.scratch\job_qm5_1003_p2.json
```

Expected output:
- JSON summary with `status=ok`, `inserted`, and `inserted_ids`.

## Phase Orchestrator Producer (P2 -> jobs queue)

`phase_orchestrator.py` is the producer for worker-pool phases. For `P2`, `--execute`
now enqueues rows into the canonical `jobs` table in `mt5_queue.db` (worker schema),
instead of launching `p2_baseline.py` directly.

```powershell
python framework/scripts/phase_orchestrator.py `
  --ea QM5_1003 `
  --execute `
  --dispatch-state D:\QM\Reports\pipeline\dispatch_state.json `
  --queue-sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --json
```

Deterministic dry-run (no queue writes):

```powershell
python framework/scripts/phase_orchestrator.py `
  --ea QM5_1003 `
  --dry-run `
  --dispatch-state D:\QM\Reports\pipeline\dispatch_state.json `
  --queue-sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --json
```

Optional override for evidence-root decisions (testing / controlled ops):

```powershell
python framework/scripts/phase_orchestrator.py `
  --ea QM5_1003 `
  --execute `
  --dispatch-state D:\QM\Reports\pipeline\dispatch_state.json `
  --pipeline-root D:\QM\reports\pipeline `
  --queue-sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --json
```

Phase selection source-of-truth:
- Orchestrator reads `dispatch_state.json -> phase_matrix_index` first for per-EA progression (`PASS` / `FAIL_*`).
- If no usable dispatch verdict exists for the EA, it falls back to report/result-file verdict discovery under `pipeline-root`.

## One-shot MT5 Saturation Evidence Bundle

Capture `before -> scheduler tick -> after` queue state in one artifact:

```powershell
python framework/scripts/mt5_saturation_evidence_once.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --dispatch-state D:\QM\Reports\pipeline\dispatch_state.json `
  --out D:\QM\reports\pipeline\mt5_saturation_evidence_once_<timestamp>.json
```

Expected artifact keys:
- `before`
- `tick`
- `after`

## Gate Evaluator (worker-pool verdict processor)

Evaluates `jobs` rows where `status='done'` and `verdict_processed_at IS NULL`, then performs:
- PASS gate checks from `framework/registry/tester_defaults.json`
- PASS roll-forward (`gen_setfile.ps1` + `deploy_ea_to_all_terminals.ps1`) + next-phase enqueue
- infra FAIL/INVALID retry handling (`no_summary_json:rc=1`, `REPORT_MISSING`, `missing_verdict`)
- strategy FAIL (`MIN_TRADES_NOT_MET`) escalation issue for Zero-Trades-Specialist

Scheduled Task target (ops): `QM_GateEvaluator_5min` (S4U), every 5 minutes.

```powershell
python framework/scripts/gate_evaluator.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --max-retries 3 `
  --limit 200 `
  --paperclip-base http://127.0.0.1:3100 `
  --company-id 03d4dcc8-4cea-4133-9f68-90c0d99628fb `
  --project-id 71b6d994-70ba-4a28-bd62-732b42a9ea58
```

Dry-run (no DB writes, no issue creation, no roll-forward side effects):

```powershell
python framework/scripts/gate_evaluator.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --dry-run
```

Template override for zero-trades dispatch body:

```powershell
python framework/scripts/gate_evaluator.py `
  --sqlite D:\QM\reports\pipeline\mt5_queue.db `
  --zero-trades-template C:\QM\repo\framework\registry\zero_trades_dispatch_template.md
```

Create/update Scheduled Task (deterministic helper):

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/register_qm_gate_evaluator_task.ps1 `
  -TaskName QM_GateEvaluator_5min `
  -RepoRoot C:\QM\repo `
  -QueueDbPath D:\QM\reports\pipeline\mt5_queue.db
```

Expected output:
- JSON payload with `task_name`, `state`, `last_run_time`, `last_task_result`, and effective command line.

Dry-run preflight (no task registration/update):

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/register_qm_gate_evaluator_task.ps1 `
  -TaskName QM_GateEvaluator_5min `
  -RepoRoot C:\QM\repo `
  -QueueDbPath D:\QM\reports\pipeline\mt5_queue.db `
  -DryRun
```
