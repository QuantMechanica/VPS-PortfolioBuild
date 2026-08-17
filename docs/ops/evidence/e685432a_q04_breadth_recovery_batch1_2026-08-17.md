# Q04 breadth recovery — staged batch 1

Date: 2026-08-17  
Router task: `e685432a-42b6-4396-9151-4ba59f03457a`  
Scope: append-only Q04 recovery only; no gate change, Factory toggle, T_Live, or AutoTrading action.

## Batch policy and headroom

The per-batch cap is **5 Q04 pairs**. The queue held 78 pending Q04 rows before this batch and 81 afterward. Q02 moved independently from 871 to 870 while the batch was being prepared. This batch added 3/5 permitted rows and then stopped; it did not unboundedly release the remaining census.

| Batch | EA | Eligible pairs | Requeued | Q04 pending before | Q04 pending after |
|---|---|---:|---:|---:|---:|
| 1 | `QM5_10413` | 3 | 3 | 78 | 81 |

Cumulative: **3 requeued / 3 eligible in the authenticated batch**. The other 19 census EAs were deferred by the batch boundary, not silently classified as eligible or excluded.

## Poison-sentinel finding

`attempt_count=99` is a deliberate do-not-retry sentinel, not ordinary retry exhaustion:

- `terminal_worker.py` writes `attempt_count=99` when it kills a log bomb and records `verdict_reason=LOG_BOMB`, `reason_classes=[LOG_BOMB]`, and `final_failure=log_bomb`.
- `requeue_stranded_infra.py` defines natural retries as 0–2, treats counts at or above 12 as poison sentinels, and explicitly refuses 99 (log bomb) and 50 (active-timeout reaper).
- The affected Q04 rows inspected here carry the genuine log-bomb markers, so they are decisions requiring repair/adjudication, not retry candidates.

Consequently these rows were not requeued:

- `QM5_10720`: EURUSD `74db28c6` and GBPUSD `beec02da`, both count 99 with genuine `LOG_BOMB` evidence.
- `QM5_10413`: SP500 `92b7e109`, count 99 with genuine `LOG_BOMB` evidence.

## Binary and registry authentication

Both inspected EAs remain `active` in `framework/registry/ea_id_registry.csv`.

- `QM5_10720`: excluded from this batch because its June EX5 was stale against the current framework and a forced governed rebuild failed closed at `time_sensitive_strategy_params_missing`. No successor was created.
- `QM5_10413`: forced governed rebuild passed with 0 errors and 0 warnings. Current EX5 SHA-256 is `e7cb954a740b0ef147bf33f96a28891912bccc13ade9fd0a4405b735843f1ff7`.

## Append-only successors

Each successor is bound to the freshly compiled EX5 SHA and preserves the terminal June Q04 row.

| Symbol | Q02 PASS predecessor | Preserved Q04 INFRA row | New Q04 row | Verified state |
|---|---|---|---|---|
| GDAXI.DWX | `dea716b8` | `00177176` | `5740d811` | pending, attempt 0 |
| NDX.DWX | `f2701a62` | `bf1feaca` | `8dc59e9a` | pending, attempt 0 |
| XAUUSD.DWX | `a2e5ea2c` | `9c727b3b` | `366b3b8a` | pending, attempt 0 |

No pipeline verdict is claimed. Q04 remains the judge of the three new rows.
