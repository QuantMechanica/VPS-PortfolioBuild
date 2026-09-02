# release_compile_wave.py backup reuse — fail-closed identity-matched dedup

Date: 2026-09-02 · Author: Claude · Router task
`ab068f38-0945-4058-8ca5-9dad25c06352` · Authority: CEO mandate 2026-09-02
(GREEN infra; deletion/retention stays OWNER-sealed, untouched)

## Symptom

`tools/strategy_farm/release_compile_wave.py::_backup` wrote a fresh ~701 MB
SQLite online backup into `D:/QM/strategy_farm/state/backups` on **every**
`apply_wave` call, unconditionally — 30+/day, including 9 backups within 90
seconds during one 2026-09-02 08:40Z retry loop. At the time the task was
filed, `state/backups` held 129 files / 68 GB logical (27 GB on disk), ~90 of
them `farm_state_before_compile_wave_*` from 2026-09-01/02 alone. D: free was
60–68 GB and `tester_cache_purge.ps1` was triggering roughly every 1.5 h.

## Fix — `tools/strategy_farm/release_compile_wave.py`

Added a cheap, fail-closed backup-reuse layer ahead of the existing
`_backup()` online-copy call. No retention/deletion logic touched (governed
by `OWNER-DEC-BACKUP-RETENTION-20260830`), no verdict logic, no farmctl claim
paths.

- `_db_identity(conn, db)` — cheap DB-image fingerprint: main-file
  `mtime_ns`/`size` (updated on WAL checkpoint), the `-wal` file's size
  (grows on any write visible to readers), and row counts of
  `work_items`, `agent_tasks`, `work_item_holds` (`IDENTITY_TABLES`).
  Returns `None` — "identity cannot be established" — if any table is
  missing/unreadable or the DB file itself is unreadable.
- `_write_identity_sidecar(backup_path, identity, backup_sha)` — writes
  `<backup>.identity.json` next to every freshly-written backup (atomic
  temp-file + `replace`), carrying the identity fields plus
  `backup_path`, `backup_sha256`, `created_at`.
- `_find_reusable_backup(backup_dir, live_identity, max_age_minutes)` —
  scans **all** `*.identity.json` sidecars in the backup dir (any backup
  "class", not just this wave's own `farm_state_before_compile_wave_*`
  prefix), keeps only those younger than `max_age_minutes`, and returns the
  newest one whose stored identity exactly matches the live identity **and**
  whose referenced backup file still exists on disk. Any unreadable/corrupt
  sidecar, missing field, or vanished backup file is skipped, never treated
  as a match.
- `_resolve_backup(conn, db, backup_dir, timeout_seconds=, reuse_max_age_minutes=)`
  — the new entry point `apply_wave` calls instead of `_backup` directly.
  Computes live identity; if establishable and a fresh matching sidecar
  exists, reuses that backup (no new I/O, no new file). Otherwise falls
  through to a full fresh `_backup()` call and best-effort writes the
  sidecar for future reuse. **Never silently skips the backup** — every
  fallback path (no live identity, no match, stale match, unreadable
  sidecar) ends in a real backup being written.
- `apply_wave` now threads a `backup_reuse_max_age_minutes` parameter
  (default `DEFAULT_BACKUP_REUSE_MAX_AGE_MINUTES = 60.0`) through to
  `_resolve_backup`, and records the outcome in the wave receipt:
  `result["backup"]` gained `"reused": bool` and `"identity_established": bool`;
  the receipt also carries `"backup_reuse_max_age_minutes"`. The
  `backup_write_guard.transaction` narrative now says `"backup reused"` vs
  `"backed up"` so a human reading one receipt can tell which happened
  without cross-referencing file timestamps.
- CLI: new `--backup-reuse-max-age-minutes` flag (default sourced from env
  `QM_COMPILE_WAVE_BACKUP_REUSE_MAX_AGE_MINUTES`, else 60 minutes); `<=0`
  disables reuse for that invocation (always fresh).
- The identity check runs on the same guarded connection
  (`_acquire_backup_write_guard`'s `BEGIN IMMEDIATE`) that already blocks
  concurrent writers before the backup step, so the identity snapshot and
  the row-count read are consistent with what was true immediately before
  this wave's own mutation — no new race window introduced.
- `_backup()` itself (the actual online-copy implementation) is untouched;
  existing `test_backup_timeout_removes_partial_snapshot` (calls `_backup`
  directly) still passes unmodified.

## Tests — `tools/strategy_farm/tests/test_release_compile_wave.py`

Added (fixture also gained an empty `agent_tasks` table so identity can be
established against the same schema `apply_wave` uses):

- `test_apply_wave_backup_records_identity_and_writes_sidecar` — a fresh
  `apply_wave` backup is `reused=False`, `identity_established=True`, and
  writes a sidecar whose `row_counts`/`backup_sha256` match the receipt.
- `test_resolve_backup_reuses_fresh_identity_matched_backup` — two
  back-to-back `_resolve_backup` calls against an unchanged DB: second call
  reuses the first backup's exact path/sha, only one `*.sqlite` file exists.
- `test_resolve_backup_does_not_reuse_after_real_db_mutation` — an `INSERT`
  between calls (genuine DB change) forces a second, distinct backup —
  fail-closed against stale reuse.
- `test_resolve_backup_ignores_sidecar_older_than_reuse_window` — a
  matching sidecar backdated past the reuse window is not reused.
- `test_resolve_backup_fails_closed_when_identity_table_missing` — a DB
  missing one of `IDENTITY_TABLES` never reuses and never writes a sidecar
  (best-effort sidecar write is skipped when identity can't be established),
  every call still produces a real backup.
- `test_resolve_backup_disabled_via_zero_max_age` — `reuse_max_age_minutes<=0`
  disables reuse per-call.
- `test_env_default_backup_reuse_max_age_minutes` — env var parsing
  (default, override, invalid-value fallback).

Run:

```
python -m pytest tools/strategy_farm/tests/test_release_compile_wave*.py -q -p no:cacheprovider
```

Result: **11 passed** (4 pre-existing + 7 new), 2.5s.

## Audit — same writer pattern elsewhere (read-only, not modified)

Per task scope, checked whether the same "unconditional full online backup
per call" pattern exists in `farmctl.py` hold/supersede paths and
`health.py`. Findings:

- **`tools/strategy_farm/farmctl.py:21649` `_governed_state_backup(root, label)`**
  — writes a fresh, full (~700 MB per its own comment at line 21998) online
  SQLite backup on **every** call with **zero** throttling or reuse check
  (unlike the hourly writer below). Called from:
  - `record_q01_smoke_successor` (line 22000, label `"q01_smoke_successor"`)
  - **`release_work_item_hold` (line 22320, label `"hold_release"`)** — this
    is literally the "hold" path named in this task's audit scope. Both call
    sites already run under a `FactoryMutationLock` immediately after the
    backup, and `release_work_item_hold` already inspects eligibility
    (`_inspect`) *before* the backup so refused releases don't litter the
    backup directory — but a genuinely eligible retry loop (same shape as
    the release_compile_wave incident) would still write a full fresh backup
    on every attempt. The same `_db_identity`/sidecar/`_find_reusable_backup`
    helper shape built here would apply directly; not implemented (out of
    this task's scope — audit only).
- **`tools/strategy_farm/farmctl.py:16768` `_supersede_stale_q09_holds_after_rebind`**
  — no independent backup writer at all; runs inside the caller's own
  `connect(root)` + `BEGIN IMMEDIATE` transaction (see call site at line
  17574) without any `_governed_state_backup`/`sqlite_backup` call around
  it. Not applicable.
- **`tools/strategy_farm/governed_work_item_hold.py:154` `sqlite_backup(db, backup_dir)`**
  — same unconditional-per-call pattern as `_governed_state_backup` (whose
  docstring explicitly says it "Mirrors ... `governed_work_item_hold.sqlite_backup`").
  Called from `apply_holds` (line 181). Not named in the task's explicit
  scope (`farmctl.py` / `health.py`) but flagged here since it is the direct
  sibling of the pattern the task asked about and shares the exact same
  fix shape. Not implemented — audit only.
- **`tools/strategy_farm/farmctl.py:16303` `_hourly_db_backup`** — already
  self-throttled: skips if the newest `farm_state_*.sqlite` in the backup
  dir is younger than 50 minutes (glob + mtime, no identity check). Not an
  offender; no action needed. Its throttle is time-only (no content/identity
  verification), unlike the reuse logic just added, but that's a much lower
  call frequency (hourly maintenance) so the gap is far less costly.
- **`tools/strategy_farm/health.py`** — `chk_db_backup_fresh` (line 1284) is
  **read-only**: it only globs `state/backups/farm_state_*.sqlite` and
  reports staleness (fails if newest > 150 min old, i.e. the hourly writer
  above has stalled). It writes no backups itself. No writer pattern present
  in `health.py`.

## Acceptance

- Backup count per day now bounded by actual DB-state changes within the
  reuse window, not call count: a retry loop against an unchanged DB (the
  reported 9-in-90s case) reuses the first call's backup for every
  subsequent attempt inside the default 60-minute window.
- Tests green (11/11, see above).
- Wave receipt records reuse (`result["backup"]["reused"]`).
- This note reported in `docs/ops/OPEN_ITEMS_STATUS.md`.

## Left open

- `farmctl.py::_governed_state_backup` (both call sites) and
  `governed_work_item_hold.py::sqlite_backup` still write unconditional full
  backups per call — same class of waste, not yet fixed (out of this task's
  scope; flagged for a follow-up ticket).
- No retention/deletion change was made or needed; `OWNER-DEC-BACKUP-RETENTION-20260830`
  still governs which of these snapshots (reused or fresh) get pruned.
