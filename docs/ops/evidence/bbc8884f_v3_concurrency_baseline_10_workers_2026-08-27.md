# V3 concurrency A/B — BASELINE_10 24-hour baseline

**Verdict:** `BASELINE_MEASURED_NO_SWITCH`

Window: `2026-08-26T10:36:09.688950+00:00` through `2026-08-27T10:36:09.688950+00:00` (24.00 h). The database was opened read-only; no worker, queue row, terminal, or concurrency-policy file was changed.

## Baseline metrics

| Metric | Result | Sample / denominator |
|---|---:|---:|
| Net execution verdicts/day | **180.000** | 180 execution rows; 2 administrative rows excluded |
| MEASURED cells/hour | **0.792** | 19 cells |
| CPU-high pause rate | **247.208** events/hour | 5933 events; log coverage complete |
| CPU-high pause density | **24.721** events/slot-hour | 10 configured slots |
| Slot utilization | **60.80%** | 145.918 / 240.000 terminal-hours |

`disposition_only` is excluded only from execution throughput and wall-time samples. Occupancy includes every terminal-bound claim because it consumed a slot.

## Median wall time by Q phase

| Q phase | Median minutes | n | Execution verdicts |
|---|---:|---:|---:|
| Q02 | 12.650 | 3 | 3 |
| Q03 | 83.700 | 10 | 10 |
| Q07 | 94.117 | 7 | 7 |
| Q09 | 13.917 | 113 | 113 |
| Q10 | 213.950 | 15 | 15 |
| Q11 | 27.350 | 1 | 1 |

The separate non-gate measurement pool had median cell wall time **7.833 min** (n=19). It is not presented as a pipeline phase; operator-facing phase labels above remain Q-only.

## Occupancy by terminal

| Terminal | Occupied hours | Window utilization | CPU-high pauses |
|---|---:|---:|---:|
| T1 | 20.187 | 84.11% | 244 |
| T2 | 12.623 | 52.60% | 380 |
| T3 | 5.531 | 23.05% | 2310 |
| T4 | 15.185 | 63.27% | 338 |
| T5 | 14.546 | 60.61% | 824 |
| T6 | 13.683 | 57.01% | 270 |
| T7 | 18.537 | 77.24% | 274 |
| T8 | 14.165 | 59.02% | 355 |
| T9 | 17.403 | 72.51% | 281 |
| T10 | 14.058 | 58.57% | 657 |

## Queue-mix anchor for a later matched window

| Q phase | Pending | Active |
|---|---:|---:|
| Q02 | 721 | 0 |
| Q03 | 110 | 0 |
| Q04 | 1428 | 0 |
| Q05 | 8 | 0 |
| Q06 | 1 | 0 |
| Q07 | 19 | 1 |
| Q08 | 8 | 0 |
| Q09 | 123 | 2 |
| Q10 | 46 | 4 |
| Q12 | 3 | 0 |

Separate non-gate measurement pool: 2063 pending, 1 active. Other non-gate work: 31 pending, 0 active.

## Phase-2 switch checklist — not executed

1. Obtain explicit review/authorization for a separate eight-worker A/B step and preregister the comparison threshold before seeing its result.
2. Match the 24-hour candidate window to the baseline queue mix, data contract, and metric code/commit; record material mix differences as confounders.
3. Select two factory terminals only after both have no active work item. Never interrupt a backtest and never include T_Live.
4. Write those two terminal names, one per line, only to the governed `D:/QM/strategy_farm/state/disabled_terminals.txt` file. The present file snapshot is `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` (0 bytes).
5. Critical implementation check: the file filters future spawns but a resident worker does not read it inside its claim loop. Therefore do not start the candidate clock until both selected daemons have exited through an authorized, non-interrupting lifecycle path and probes show exactly eight enabled daemons.
6. Run this same read-only harness for an exact 24 hours as `CANDIDATE_8`; compare execution verdicts/day, MEASURED cells/hour, CPU-high pause density, Q-phase medians, utilization, and queue mix. Pipeline verdicts remain untouched.
7. Rollback is exactly an empty `disabled_terminals.txt` (zero bytes; SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`). Let the governed spawner restore eligible workers; never start `terminal64.exe` manually.

## Measurement caveats

- Timestamped worker-log coverage: **complete**. A partial window makes the CPU-high pause result a lower bound and invalidates a strict A/B comparison.
- Rows skipped from wall-time because claim time was absent: 0.
- Rows skipped from utilization because claim/terminal binding was absent: 2.
- Utilization intervals are clipped to the window and merged per terminal, so retries/overlaps cannot produce more than 100% utilization for one terminal.
