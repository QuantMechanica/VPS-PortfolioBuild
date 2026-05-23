# Cascade Chain Orchestration - 2026-05-18

Status: historical. Current automation is governed by the Q-Series hard-gate map in `PIPELINE_PHASE_SPEC.md` and `PIPELINE_PHASE_ID_MAP.md`.

2026-05-20 hardening note: `REPORT_ONLY`, `MULTI_SEED_MIXED`, proxy P7 rows, and synthetic P8 news matrices are not promotable evidence. Q08, Q09, Q10, and Q11 require the real-evidence semantics described in the current phase spec.

`farmctl.py` now treats P3.5 through P8 as real phase-driver work, with shared EA-scoped artifacts under:

`D:/QM/reports/pipeline/<ea_id>/<phase>/`

## Phase Inputs And Outputs

| Phase | Driver | Required input | Primary output |
|---|---|---|---|
| P3.5 | `framework/scripts/p35_csr_runner.py` | Optional `P2/report.csv`, optional `P3/report.csv` when present | `P3.5/summary.json` |
| P4 | `framework/scripts/p4_walk_forward.py` | Optional `P4/walk_forward.csv` when present | `P4/summary.json`, `P4/report.csv`, operator-supplied `P4/calibration.json` for later phases |
| P5 | `framework/scripts/p5_stress_driver.py` | `P4/calibration.json` | `P5/p5_clean_metrics.json`, `P5/p5_stress_metrics.json`, `P5/p5_slices.csv` when crisis slices are prepared |
| P5b | `framework/scripts/p5b_noise_driver.py` | `P4/calibration.json` | `P5b/p5b_trials.csv` |
| P5c | `framework/scripts/p5c_crisis_slices.py` | `P5/p5_slices.csv` | `P5c/summary.json` |
| P6 | `framework/scripts/p6_multiseed_driver.py` | None beyond EA, symbol, setfile, year, period | `P6/p6_seeds.csv` |
| P7 | `framework/scripts/p7_statval.py` | `P3/sweep_pass_rows.csv`, `P6/p6_seeds.csv` | `P7/summary.json`; `P7/news_matrix.csv` when prepared for P8 |
| P8 | `framework/scripts/p8_news_driver.py` | `P7/news_matrix.csv`, falling back to `D:/QM/data/news_calendar/news_matrix.csv` | `P8/summary.json`, `P8/P8_summary.csv` |

## Promotion Semantics

Cascade work items are not allowed to fake a runner result.

`WAITING_INPUT` means the real runner exists, but a required upstream file is missing. The dispatcher records `missing_inputs` in `payload_json` and releases the terminal without spawning a process.

`PENDING_RUNNER` means no runnable script is available for the phase. This should be rare for P3.5 through P8 after the 2026-05-18 wiring.

`FAIL`, `PASS`, `REPORT_ONLY`, and `MULTI_SEED_MIXED` come from runner `summary.json` or from the driver artifact schema when a driver writes CSV/JSON outputs instead of a summary. P5 is classified from clean/stress metric JSON, P5b from `p5b_trials.csv`, and P6 from `p6_seeds.csv`.

## Recovery

For a stuck `WAITING_INPUT` row:

1. Inspect `payload_json.missing_inputs` in `D:/QM/strategy_farm/state/farm_state.sqlite`.
2. Produce or copy the missing file into `D:/QM/reports/pipeline/<ea_id>/<phase>/`.
3. Re-trigger the cascade phase:

```powershell
python tools/strategy_farm/farmctl.py enqueue-cascade-backtest --ea QM5_9999 --phase P5
python tools/strategy_farm/farmctl.py dispatch-tick
```

If an existing row stayed `done/WAITING_INPUT`, requeue the same phase after the file lands; `enqueue_cascade_backtest_for_ea` resets completed successor rows to `pending` for the same EA, symbol, and setfile.
