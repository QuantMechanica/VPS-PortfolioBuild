# OWNER backup-retention execution receipt

- Router task: `4c0a5ae7-d280-441d-b004-87c151c1eee7`
- Authority: `OWNER-DEC-BACKUP-RETENTION-20260830`
- Sealed aggregate manifest SHA-256: `0c3385c1bc0d9e5bc4a059eefcedeb5fffd666796223b366c6bc4a41b7b5c032`
- Execution window: `2026-08-31T14:46:09+00:00` through `2026-08-31T15:47:11+00:00`
- Branch: `agents/board-advisor`

## Verdict

`REVIEW` — the approved retention execution is complete. Receipt verification
returned zero errors. The executor did not traverse `D:/QM/reports/state`, any
`Custom_master` tree, or any `T_Live` tree; it did not mutate a database row,
terminal, AutoTrading state, verdict, decision, or git evidence outside the
artifacts named below.

## Applied result

| operation | files | logical/source bytes | measured allocated saving |
|---|---:|---:|---:|
| verified quarantine then deletion | 43,282 | 51,016,477,874 (47.513 GiB) | recorded per volume/batch |
| NTFS compression of retained set | 206,165 | 11,052,864,144 (10.294 GiB) | 6,768,406,532 (6.304 GiB) |
| included old farm-state snapshot rotation | 8 | 2,631,806,976 | included in deletion total |

The host free-space observation moved from:

- `C:` 95,143,882,752 -> 101,723,475,968 bytes free (`+6.128 GiB`)
- `D:` 92,262,891,520 -> 141,295,030,272 bytes free (`+45.665 GiB`)
- combined observed delta: `+55,611,731,968` bytes (`+51.792 GiB`)

The observed volume delta is not used as a deletion verdict because the live
farm wrote and released other files concurrently. The authoritative action
totals are the exact-path receipt sums above. Compression savings use
`GetCompressedFileSizeW` before/after measurements.

## Drift and fail-closed handling

The final pre-action dry run classified 504,114 files and held 7,904 action-like
paths (8,924,939,604 bytes) because they were post-seal/new/changed, belonged to
an action group absent from the seal, or exceeded a sealed aggregate bound.
Two forbidden boundaries and one unreadable directory were not traversed.

The first live invocation completed 39 valid deletion batches, then stopped on
Windows path-length error 206 before moving the failing path. At that point:

- 11,675 files / 19,513,426,131 logical bytes had valid delete receipts.
- 483 files / 309,763,936 bytes remained in the interrupted same-volume
  quarantine (35 post-move drift detections plus the unreceipted partial batch).
- A read-only recovery plan mapped all 483 to vacant original paths; all 483
  were restored and both interrupted quarantine roots were removed.

The resumed executor used flat SHA-256 quarantine names, eliminating path
growth. It deleted another 31,607 files / 31,503,051,743 bytes, compressed the
complete eligible retained set, and rotated eight old snapshots. Sixty-three
files / 45,231,074 bytes changed identity or could not be exclusively opened
during deletion and were held. Verification later found those transient log
paths absent through normal live-farm cleanup; they were never deleted by this
executor.

Thirty-five fast-changing files were protected in the resume quarantine. A
second dry recovery found their original paths vacant; all 35 / 3,506,938 bytes
were restored without overwrite. Both resume quarantine roots are empty.
Receipt-level `recoverable_quarantine_files=70` counts the same protected 35
files once in each invocation; it is not 70 distinct files.

## Database and factory guards

- Initial and post-run live `PRAGMA quick_check`: `ok`.
- A fresh `PRAGMA quick_check=ok` was recorded immediately before the eight
  database-rotation batches; each snapshot was content-hashed after quarantine
  and before unlink.
- Batches were capped at 5,000 files and 512 MiB and delayed according to live
  active-row samples (3-7). Windows background-I/O mode was unavailable
  (`background_io_mode=false`), so bounded batching and active-load delay were
  the operative throttle.
- No worker, terminal, backtest, `T_Live`, or AutoTrading process/state was
  interrupted or changed.

## Verification

- Focused tests: `9 passed` (`test_build_backup_retention_manifest.py` plus
  `test_execute_backup_retention_phase2.py`).
- Durable batch receipts: 153 total (109 quarantine/delete, 44 compression).
- Receipt artifact population: 311 files / 10,366,048 bytes before this
  markdown receipt.
- Full verifier: `error_count=0`; every gzip receipt hash and canonical
  exact-path hash matched, all 206,165 retained files existed with the NTFS
  compressed attribute set, all recoverable quarantine entries had a recovery
  binding, and zero quarantine files remained.
- Verifier warnings: 63, exactly the held transient-log paths later absent from
  normal farm cleanup; no warning indicates executor deletion or evidence loss.

## Durable artifacts

- Dry-run expansion:
  `docs/ops/evidence/2026-08-31_4c0a5ae7_backup_retention_phase2_dry_run.json`
  (`sha256:add86abc19c79b3073fc77186ba1f7fa5d5ede7eec352b64562220799ff5ae4b`)
- Initial-run receipts and legacy recovery:
  `docs/ops/evidence/2026-08-31_4c0a5ae7_backup_retention_phase2_receipts/`
- Resume receipts, run summary, and flat recovery:
  `docs/ops/evidence/2026-08-31_4c0a5ae7_backup_retention_phase2_receipts_resume1/`
- Resume run-summary SHA-256:
  `a6201114fe527df1edd2bdfd3dfe6f9dd2270bf3baca4b387a971bdd2b3e5622`
- Full verification:
  `docs/ops/evidence/2026-08-31_4c0a5ae7_backup_retention_phase2_verification.json`
  (`sha256:d372c45a0d8af55a3209da218e15f4f686b4e9c140693bf18eca2a7cd865a09f`)
- Repeatable tooling:
  `tools/strategy_farm/execute_backup_retention_phase2.py`,
  `tools/strategy_farm/recover_backup_retention_phase2_quarantine.py`, and
  `tools/strategy_farm/verify_backup_retention_phase2.py`.
