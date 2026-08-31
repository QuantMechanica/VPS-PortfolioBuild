# OWNER backup-retention phase-1 sealed classification manifest

Generated UTC: `2026-08-31T07:45:40+00:00`  
Authority: `OWNER-DEC-BACKUP-RETENTION-20260830`  
CSV SHA-256: `0c3385c1bc0d9e5bc4a059eefcedeb5fffd666796223b366c6bc4a41b7b5c032`

## Verdict

`REVIEW` — classification only. No report, log, backup, database row, live file, or terminal state was mutated. Phase 2 is forbidden until Orchestrator approval of this seal.

## Measured inventory

- Aggregated manifest rows: 56,860
- Files classified: 500,985
- Bytes inventoried: 208,450,818,129
- Projected deletable bytes: 58,304,237,459 (54.30 GiB)
- Retained bytes eligible for compression: 11,221,422,952 (10.45 GiB)
- Mechanically protected path-to-25 pairs: 2,536
- Live farm DB `PRAGMA quick_check`: `ok`
- Snapshot max `work_items.updated_at`: `2026-08-31T07:45:39+00:00`

| disposition | files | bytes | projected free | compression candidate |
|---|---:|---:|---:|---:|
| `COMPRESS_KEEP_COMPLETE_CHAIN` | 138,931 | 8,054,929,351 | 0 | 8,054,929,351 |
| `COMPRESS_KEEP_Q02_Q04` | 70,262 | 3,166,493,601 | 0 | 3,166,493,601 |
| `DELETE_DB_ROTATION` | 8 | 2,631,806,976 | 2,631,806,976 | 0 |
| `DELETE_LOG` | 29,347 | 54,607,482,396 | 54,607,482,396 | 0 |
| `DELETE_NONRETAINED` | 15,740 | 1,064,948,087 | 1,064,948,087 | 0 |
| `KEEP_ALREADY_COMPRESSED` | 35,049 | 486,065,652 | 0 | 0 |
| `KEEP_AMBIGUOUS` | 154,985 | 37,655,553,605 | 0 | 0 |
| `KEEP_DB_ROTATION` | 133 | 97,117,179,904 | 0 | 0 |
| `KEEP_DL090_OPEN` | 4,505 | 668,956,524 | 0 | 0 |
| `KEEP_OUT_OF_SCOPE` | 52,022 | 2,997,402,033 | 0 | 0 |
| `NEVER_TOUCH` | 3 | 0 | 0 | 0 |
| `PAIR_TAG_ONLY` | 0 | 0 | 0 | 0 |

## Mechanical classification

A pair is path-to-25 when at least one live snapshot condition holds: an open pipeline/optimization row; any OPT_CENSUS program row; a v4 PASS-family row; a non-retired portfolio-candidate row; or a resolvable in-flight REQUAL/recovery/opt-fork agent task. All non-log evidence for those pairs is retained. Other pairs retain only Q02/Q04 files in the DL-090 artifact set (`report.htm/html`, summary/aggregate JSON, tester INI, and setfiles). Logs are deletion candidates. Open work items override deletion. Unknown pair/phase identity is kept.

Farm-state backups are classified by the union of the newest 10 and files modified in the trailing 14 days. A phase-2 executor must repeat `PRAGMA quick_check` immediately before any backup rotation; this phase-1 quick check is evidence, not future authorization.

## Explicit exclusions and phase-2 gates

- `D:/QM/reports/state`, any `Custom_master` tree, and any `T_Live` tree are not traversed into the deletion inventory.
- Git-tracked decisions/evidence, live account artifacts, verdict rows, and terminal state are outside scope.
- This CSV is aggregated evidence, not an exact-path deletion list. Phase 2 must expand exact paths, detect drift against this CSV seal, quarantine before deletion, and emit per-batch byte/hash receipts.
- A locked, newly active, missing, changed, or unclassifiable path defaults to KEEP in phase 2.
- No predicted compression saving is asserted; only the measured input bytes eligible for compression are reported.

## Source roots

- `D:\QM\reports`
- `D:\QM\strategy_farm\logs`
- `C:\QM\backups_relocated`
