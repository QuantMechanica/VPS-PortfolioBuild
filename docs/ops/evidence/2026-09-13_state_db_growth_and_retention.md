# Q state database growth and retention — task f5d30fc9

**RESULT (Q-only): REVIEW — the growth cause is measured and the Default-OFF
archive/retention implementation passes focused tests; no production backup,
database row, WAL, or terminal was changed.**

## Growth attribution

The before image is the durable pre-schema snapshot
`D:/QM/strategy_farm/state/farm_state.pre_prescreen_taxonomy_20260912T1143Z.sqlite`.
The after image is the live database, observed read-only. SQLite in this Python
build has no `dbstat` module, so the per-table evidence is exact row count rather
than an invented page allocation. Page-level totals are exact PRAGMA values.

| physical measure | before | after | delta |
|---|---:|---:|---:|
| file bytes | 816,766,976 | 1,266,081,792 | +449,314,816 |
| 4,096-byte pages | 199,406 | 309,102 | +109,696 |
| free-list pages | 1 | 103,228 | +103,227 (+422,817,792 bytes) |
| used pages (page count minus free list) | 199,405 | 205,874 | +6,469 (+26,497,024 bytes) |

Thus 94.1% of the physical growth is reusable free-list space, consistent with
the governed PRESCREEN schema rebuild, not live journal payload. A quiet-window
`VACUUM` can return it to the filesystem. The material live-row growth is still
worth bounding: events increased by 92,926 rows at the final probe; 91,864 are
`routing_awaiting_decision_bound_agent`. Their combined new `detail_json` is
14,738,794 bytes.

### Exact per-table row census

| table | before | after | delta |
|---|---:|---:|---:|
| sources | 118 | 118 | 0 |
| tasks | 8,897 | 8,924 | +27 |
| events | 410,240 | 503,166 | +92,926 |
| agent_registry | 4 | 4 | 0 |
| agent_tasks | 2,236 | 2,259 | +23 |
| portfolio_candidates | 41 | 41 | 0 |
| spawn_leases | 45 | 43 | -2 |
| ea_metrics | 96,917 | 98,557 | +1,640 |
| ingest_phase_aggregate_ledger | 23 | 23 | 0 |
| claim_class_ledger | 64 | 64 | 0 |
| poison_pill_quarantine | 219 | 219 | 0 |
| work_item_holds | 4,433 | 4,468 | +35 |
| work_item_transition_ledger | 3,238 | 3,282 | +44 |
| agent_task_transition_ledger | 69 | 69 | 0 |
| build_task_reconciliation_ledger | 2 | 2 | 0 |
| parent_task_transition_ledger | 424 | 455 | +31 |
| event_dedupe_state | 23 | 23 | 0 |
| q09_news_schema_meta | 1 | 1 | 0 |
| work_item_contracts | 0 | 0 | 0 |
| news_calendar_bundles | 1 | 1 | 0 |
| news_calendar_bundle_files | 2 | 2 | 0 |
| q09_news_tests | 183 | 183 | 0 |
| q09_news_cells | 1,937 | 1,937 | 0 |
| q09_news_arms | 134 | 134 | 0 |
| candidate_qualifications | 0 | 0 | 0 |
| q09_news_migration_runs | 0 | 0 | 0 |
| factory_runtime_activation_consumptions | 1 | 1 | 0 |
| factory_runtime_activation_consumptions_v2 | 35 | 35 | 0 |
| q09_news_cell_occurrences | 2,418 | 2,418 | 0 |
| work_item_supersedes | 1,521 | 1,526 | +5 |
| router_writer_contract | 1 | 1 | 0 |
| work_item_dependencies | 368 | 368 | 0 |
| gate_contract_activations | 2 | 2 | 0 |
| gate_contract_cutover_log | 28 | 28 | 0 |
| gate_contract_provenance_repairs | 3 | 3 | 0 |
| work_items | 148,128 | 148,327 | +199 |

## Implemented policy

`continuous_retention_runner.py` now classifies only the two governed backup
families. It keeps the newest eight scheduled hourly snapshots; keeps mutation
snapshots for 48 hours; protects an exact snapshot named in any open work-item
payload, evidence binding, or bounded JSON receipt; and applies a 10 GiB cap by
removing only unprotected candidates, oldest first. If the newest-eight plus
open references alone exceed the cap, it reports `cap_satisfied=false` rather
than deleting protected material. Every dry-run decision contains `KEEP` or
`DELETE` plus its rule. Unrelated SQLite files, the live DB, WAL, and SHM do not
match the candidate regexes.

The scheduled hourly producer retains the newest eight by count when
`QM_HOURLY_DB_BACKUP_KEEP8=1`; with the Default-OFF gate absent it preserves
the temporary six-hour policy. It never touches `farm_state_before_*` mutation
anchors.

The optional state-journal path requires both `--archive-state-journals` and
`--apply`. It checks that no work item is active/claimed/in-progress, acquires
the factory mutation lock, exports old `events` rows in ID order to a new JSONL
under `D:/QM/reports/state/archive/`, fsyncs and SHA-256 binds it, checks the
export count, deletes exactly the bound ID/cutoff cohort in `BEGIN IMMEDIATE`,
then VACUUMs and requires `PRAGMA quick_check=ok`. Existing archive targets are
never overwritten. The default 30-day policy remains OFF until an operator
selects a governed quiet window.

## Production dry run and verification

Command:

```text
python tools/strategy_farm/continuous_retention_runner.py --noop-free-bytes 1099511627776 --retention-plan-only --governed-state-retention --archive-state-journals --journal-keep-days 30
```

Receipt:
`D:/QM/reports/state/continuous_retention/20260913T120120Z/run_summary.json`

- `PASS_PLAN_ONLY`, live DB quick-check `ok`.
- 20 governed snapshots examined: seven hourly plus one mutation retained,
  12 unreferenced mutations proposed for hard-cap deletion.
- Planned retained bytes: 10,128,654,336; cap satisfied.
- Open-receipt references found: zero. The test fixture proves an old named
  backup is retained with reason `OPEN_RECEIPT_REFERENCE`.
- Default-OFF 30-day event plan: 334,684 rows / 44,414,091 logical detail bytes.
- No `--apply` was supplied; all 20 snapshots and every database row remained.

Focused verification:

```text
python -m pytest -q tools/strategy_farm/tests/test_continuous_retention_runner.py tools/strategy_farm/tests/test_hourly_db_backup.py
```

Result: **19 passed**. Tests include open-receipt protection, cap ordering,
hourly newest-eight isolation, append-before-delete/hash verification, exact
row-count deletion, post-VACUUM integrity, and Default-OFF behavior.

## Rework closure

The previously reported `news_calendar_taint` backup churn is resolved by
commit `7d1e16253d`: `news_calendar_taint.sweep` performs a read-only
preflight and takes the governed backup plus mutation lock only when a row
actually needs `HOLD` or `RELEASE`. This closes the required rework item; the
optional live-DB `PRAGMA data_version` backup-reuse enhancement is not part of
this task’s acceptance and was not introduced here.
