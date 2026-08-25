# Q02 stranded recovery execution — 2026-08-25

- Router task: `3a94735c-90de-442a-b8a9-76b97ae89979`
- Approved census: `docs/ops/evidence/2026-08-24_q02_stranded_pairs_census.csv`
- Approved plan: `docs/ops/evidence/2026-08-24_q02_stranded_pairs_census_and_recovery_plan.md`
- Execution window: 2026-08-25 19:15–20:16 UTC
- Scope: only the 72 rows classified `RECOVERABLE_MIXED_TRANSIENT`
- Result: **38 append-only Q02 successors; 34 justified guard skips**
- Final farm metric: `q02_stranded_exhausted_pairs=50` (initial 88 minus 38 successors)

## Outcome

| batch | approved pairs | successors | guarded skips | stranded after batch |
|---:|---:|---:|---:|---:|
| 1 | 10 | 5 | 5 | 83 |
| 2 | 7 | 2 | 5 | 81 |
| 3 | 10 | 10 | 0 | 71 |
| 4 | 9 | 3 | 6 | 68 |
| 5 | 8 | 2 | 6 | 66 |
| 6 | 7 | 5 | 2 | 61 |
| 7 | 10 | 3 | 7 | 58 |
| 8 | 9 | 6 | 3 | 52 |
| 9 | 2 | 2 | 0 | 50 |
| **total** | **72** | **38** | **34** | — |

The 34 skips are fail-closed outcomes from the canonical enqueue path:

- 33: `q02_rerun_source_evidence_missing`. The historical terminal evidence file/binding could not be authenticated, so no successor was created.
- 1: `missing_setfile` for `QM5_12486/GBPUSD.DWX` source `11abcc49-c00f-482b-b1ca-4428c3a03972`. A runnable current setfile was absent, so no successor was created.

Every approved row therefore has a durable disposition: exactly one successor or a documented guard skip. Full UUID-level results are in `2026-08-25_q02_stranded_recovery_dispositions.csv`.

## Headroom log

The plan required `mt5_worker_saturation` to be OK/WARN and at least two idle T1–T10 slots before every batch. Every admission met both conditions.

| gate / probe (UTC) | health overall / FAIL count | saturation | idle slots | q02 stranded |
|---|---|---|---:|---:|
| pre batch 1 — 19:15:56 (slots 19:16:31) | FAIL / 16 | OK 10/10 | 3 | 88 |
| post 1 / pre 2 — 19:22:06 | FAIL / 15 | OK 10/10 | 5 | 83 |
| post 2 / retry / pre 3 — 19:28:35 | FAIL / 15 | OK 10/10 | 3 | 81 |
| post 3 / pre 4 — 19:33:16 | FAIL / 16 | OK 10/10 | 6 | 71 |
| post 4 / retry / pre 5 — 19:37:37 | FAIL / 15 | OK 10/10 | 3 | 68 |
| post 5 / pre 6 — 19:41:04 | FAIL / 15 | OK 10/10 | 4 | 66 |
| post 6 / pre 7 — 19:45:01 | FAIL / 15 | OK 10/10 | 3 | 61 |
| post 7 / pre 8 — 19:52:58 | FAIL / 16 | WARN 9/10 | 5 | 58 |
| batch 8 reconciliation — 20:07:42 | FAIL / 14 | OK 10/10 | 3 | 57 |
| post 8 / pre 9 — 20:13:04 | FAIL / 15 | OK 10/10 | 2 | 52 |
| post 9 / final — 20:16:22 | FAIL / 15 | OK 10/10 | 5 | 50 |

The farm-wide overall state was already FAIL before execution and remained FAIL because of unrelated standing checks. The admission signals named by the approved plan never failed. The stranded metric fell by exactly the number of successful successors at every reconciliation point.

## Verification

Read-only verification against `D:/QM/strategy_farm/state/farm_state.sqlite` after the final batch established:

- 72/72 source rows remain terminal (`done` or legacy `failed`) with verdict `INFRA_FAIL`; no historical verdict or evidence row was overwritten.
- 38/38 admitted rows have exactly one successor with the exact source UUID in `append_only_rerun_of_work_item`.
- All 38 successors have `historical_work_item_preserved=true`.
- All 38 successors use fixed-risk settings: `risk_fixed > 0` and `risk_percent = 0`.
- All 38 successors retain the staged recovery reason with their batch number.
- At evidence seal time all 38 successors were `pending` with no verdict. No pipeline or economic verdict is claimed here.
- 72/72 current EX5 hashes still match the approved census.
- The 16 deterministically dead census rows have zero exact successors and were not touched.
- No T1–T10 backtest was interrupted; no terminal was started manually; T_Live and AutoTrading were not changed.

## Execution notes

The current canonical CLI requires the same terminal source UUID in both `--from-work-item-id` and `--append-only-rerun-of`. Both were supplied for every acting call, adding an exact-source constraint while retaining the approved append-only behavior.

Transient SQLite lock errors in batches 2 and 4 were retried only after fresh health/slot checks; the retried rows then resolved to the documented evidence-missing guard. Batch 8's combined admission process exceeded a bounded wait after committing one row. Only that control-plane process was stopped; no terminal/backtest was affected. Exact DB reconciliation found one successor and eight untouched rows, which were then processed individually after another health/slot check.

One manually transcribed batch-8 hash attempt was rejected as `current_ex5_hash_mismatch` before any write. The actual row was immediately retried with UUID and hash sourced directly from the approved CSV and created exactly one successor. That no-op rejection is not counted as a cohort disposition.
