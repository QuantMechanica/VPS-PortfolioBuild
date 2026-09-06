# M14 — Isolated Restore Test of the Production Backup (farm_state + evidence bundle)

- **Task id:** `18b6e054-3f65-4792-922f-b7aa5c713241` (M14, Priority 1, from CEO Audit finding 4 / E12–E14)
- **Date:** 2026-09-06 (measurement window 03:04Z–03:10Z)
- **Executed on:** Claude agent lane (orchestrator-queued ops measurement)
- **Scope of this document:** the *isolated restore test* with measured RPO/RTO, plus a backup-continuity and space-trend assessment. Per the queuing instruction this task delivers **one evidence file only**; the retention-lock code fix and the threshold reconciliation (payload parts 2–3) are **documented as findings with file:line anchors and a recommended safe fix, but NOT implemented here** (they require code changes outside this single-file mandate).
- **Method guardrails:** live DB `D:/QM/strategy_farm/state/farm_state.sqlite` opened **read-only** (`?mode=ro`) only; backups were **copied into a scratch temp dir and opened there** — production was never restored over; no writer/task/terminal was stopped or started; no T_Live access.

## 1. Backup mechanisms found

Two independent producers write a farm_state backup (verified in source, not by claim):

| Mechanism | Producer (file:line) | Scheduler | Destination | Cadence (config) | Evidence bundle? |
|---|---|---|---|---|---|
| On-box scheduled snapshot | `_hourly_db_backup` `tools/strategy_farm/farmctl.py:17897-17928`, called from `pump_maintenance` `farmctl.py:23314-23338` | `QM_StrategyFarm_PumpMaintenance_Hourly` (State=Ready; Last 2026-09-06 04:00 local / 02:00Z, result 0x0) | `D:/QM/strategy_farm/state/backups/farm_state_YYYYMMDD_HHMM.sqlite`, 24h retention | hourly (`install_pump_maintenance_scheduled_task.ps1:14`, RepetitionInterval 1h) | no (DB only) |
| Off-box nightly bundle | `scripts/backup_nightly.ps1` (online sqlite3 `.backup()` on a `mode=ro` source) | `QM_NightlyBackup_Vault` (Last 2026-09-06 04:45 local / 02:45Z, result 0x0) | `G:/…/11 Backups/YYYYMMDD/` → `farm_state_YYYYMMDD.sqlite` + `T_Live/` + `reports_state/` + `framework_registry/` | daily | **yes** (farm_state + T_Live config + reports state + registries) |

A third class of files in `state/backups/` — `farm_state_before_<label>_<stamp>.sqlite` — are **governed pre-mutation snapshots** written by apply scripts (compile-wave, hold-release, q02-intake, dl089, canonical-setfile-paths, …) before they mutate the DB. They are point-in-time restore points but are **not a scheduled backup**; their availability depends on mutation activity, not on a cadence.

Off-box continuity is intact — one `farm_state_YYYYMMDD.sqlite` (734,773,248 bytes) at ~02:45Z for **8 consecutive days** (2026-08-30 … 2026-09-06), no gaps.

## 2. Backup selected for the restore test

Both the audit's named "farm_state + evidence bundle" and the freshest copy is the **off-box nightly bundle**, so it is the **primary** restore target; the most-recent **on-box scheduled snapshot** is validated as the secondary/local path. Neither is a pre-mutation snapshot.

| Field | Off-box (primary) | On-box scheduled (secondary) |
|---|---|---|
| Path | `G:/My Drive/QuantMechanica - Company Reference/11 Backups/20260906/farm_state_20260906.sqlite` | `D:/QM/strategy_farm/state/backups/farm_state_20260905_1800.sqlite` |
| Size (bytes) | 734,773,248 | 734,773,248 |
| mtime (UTC) | 2026-09-06T02:45:26Z | 2026-09-05T18:00:49Z |
| sha256 (source == copy) | `6d8df5a5a8297ec553a6b8fc8d2c87d53da628f518e6039c79e00bfc3342b6f3` | `dff7754da3d96086d7fe25b47bead1cf19490ea161dc1cb9a4be6bc121d4e5cb` |

## 3. Restore-test steps, timings, results

Reference clock: NOW = **2026-09-06T03:07:41Z**. Live DB at that moment: `work_items`=139091, `agent_tasks`=2054, `work_item_holds`=3691, `work_item_transition_ledger`=2860; live `max(work_items.updated_at)`=2026-09-06T03:07:25Z.

| Step | Off-box | On-box | Result |
|---|---|---|---|
| Copy backup → scratch | 1.39 s | 1.97 s | OK |
| sha256(source)==sha256(copy) | 0.81 s / 1.42 s | 0.78 s / 0.78 s | **match=True** |
| `PRAGMA integrity_check` (on copy, RW) | 6.62 s | 6.36 s | **ok** |
| `PRAGMA quick_check` (on copy, RW) | 2.08 s | 2.00 s | **ok** |

Row counts in the restored copies (delta vs live):

| Table | Live | Off-box (Δ) | On-box (Δ) |
|---|---|---|---|
| work_items | 139091 | 139090 (−1) | 139030 (−61) |
| agent_tasks | 2054 | 2054 (0) | 2039 (−15) |
| work_item_holds | 3691 | 3691 (0) | 3669 (−22) |
| work_item_transition_ledger | 2860 | 2860 (0) | 2825 (−35) |
| max(work_items.updated_at) | 2026-09-06T03:07:25Z | 2026-09-06T02:44:38Z | 2026-09-05T18:00:32Z |

Verdict fidelity — two samples of 5 recent `work_items`:
- **5 most-recently-updated live rows:** all 5 ids **present** in both backups; verdicts differ only on rows whose live `updated_at` is *after* the backup point (i.e. pure restore-point lag, not corruption).
- **5 recent rows updated before the backup point (stable rows):** verdicts **identical** in both backups — `ALL_MATCH=True` for off-box and on-box. This confirms the backups faithfully preserve verdicts; the apparent mismatches above are lag, by construction.

## 4. Restore-point lag (RPO) and restore time (RTO)

**RPO (measured lag of backup's newest committed change vs NOW):**
- Off-box nightly bundle: NOW − 2026-09-06T02:44:38Z = **≈ 23.0 min** at test time. Cadence is **daily**, so this is favourable timing (tested ~22 min after the 02:45Z run); **worst-case off-box RPO ≈ 24 h**.
- On-box scheduled snapshot: NOW − 2026-09-05T18:00:32Z = **≈ 9.1 h (≈ 547 min)**. Nominal cadence is hourly, so this is a **stall**, not the design point (root cause in §5).
- Governed pre-mutation snapshots give finer granularity (newest ~02:50Z, ≈ 18 min old) but are **not** a guaranteed-cadence backup.

**RTO (measured DB restore-and-validate, warm cache):**
- Off-box: copy 1.39 s + `integrity_check` 6.62 s (+ `quick_check` 2.08 s) = **≈ 8.0–10.1 s**.
- On-box: copy 1.97 s + `integrity_check` 6.36 s (+ `quick_check` 2.00 s) = **≈ 8.3–10.3 s**.
- These cover copy + integrity verification of a valid, openable DB. Full **operational** RTO (quiesce writers, swap the file into place, restart the farm) is larger and was **not** measured. The G: copy was fast (1.39 s) because GoogleDriveFS had the file materialised locally; a **cold** off-box pull adds 734 MB of network download.

## 5. Continuity assessment and defects (file:line anchors)

**Off-box (G:) continuity — GOOD.** Daily bundle present and fresh for 8 consecutive days; last run 02:45Z result 0x0. This is the reliable durable copy, and it is **not** affected by the on-box guard bug (it uses its own `.backup()` on a `mode=ro` source).

**On-box scheduled snapshot continuity — BROKEN.** Observed `farm_state_YYYYMMDD_HHMM.sqlite` UTC times: 09-04 18:00, 09-04 22:00, 09-05 02:00, 09-05 06:00, **then a 12 h gap to 09-05 18:00, and none since** (9 h and counting), even though `PumpMaintenance_Hourly` is configured hourly and its 02:00Z run returned 0x0. Root cause and coupled defects:

1. **Guard-masking in `_hourly_db_backup` (`farmctl.py:17904-17910`).** The 50-minute skip guard is computed from `backup_dir.glob("farm_state_*.sqlite")`, which also matches the governed `farm_state_before_*.sqlite` snapshots. Those are written many times per hour by apply scripts, so a `before_*` file is almost always <50 min old and the scheduled snapshot is **silently skipped** (the 02:00Z run had a `before_first_q02_intake` snapshot at 01:58Z, ~2 min prior). The task exits 0 while producing nothing.
2. **Health check masked by the same glob (`health.py:1314` inside `chk_db_backup_fresh`, 1285-1330).** `chk_db_backup_fresh` uses `glob("farm_state_*.sqlite")` and takes the newest mtime, so it sees the fresh `before_*` snapshots and reports **OK** while the scheduled cadence has stalled for 9 h — the durability gap is invisible on the health surface. STALE_MIN=150 assumes hourly cadence (`health.py:1305`), which the deployed producer no longer meets.
3. **Cadence config vs observed.** `install_pump_maintenance_scheduled_task.ps1:14` sets RepetitionInterval = 1 h, but the live task's Next-run is +4 h from Last and the best observed snapshot spacing is 4 h. (State observation; the exact 4h-vs-1h cause — RepetitionDuration default vs guard interaction — was not fully isolated and is flagged, not asserted.)

**Retention runner chronic FAIL_CLOSED.** `continuous_retention_runner.py` fail-closed **16 of 32 runs in the last 24 h** with `PermissionError [WinError 32]` while moving an actively-open worker log (`D:/QM/strategy_farm/logs/terminal_worker_T8.log.err`) into its quarantine dir during the log-delete step (telemetry `D:/QM/reports/state/backup_retention_continuous.jsonl`; fail timestamps include 2026-09-06T01:36:25Z, 02:21:13Z, 03:06:00Z). Backups are **not** wrongly deleted (backup deletion precedes log handling and `backup_delete.deleted_files`=0 in PASS runs), but the whole pass aborts, leaving `.continuous_retention_quarantine_*` dirs behind and the failure is unmonitored.
- **Recommended safe fix (NOT applied here — out of scope for this single-file task):** in the log rotate/delete step, attempt an exclusive open first; on `WinError 32` record the file as `SKIPPED_LOCKED` in telemetry and **continue the run** instead of fail-closing — same skip-with-log pattern already used for open work-item paths. Deliver behind the existing `--apply` flag with a dry-run first (per commit_rules).

## 6. 24-hour space trend

From `backup_retention_continuous.jsonl` (32 runs / 24 h): free space oscillated **62.4 – 85.1 GiB**, currently ~80.9 GiB; net **−4.17 GiB** over the sampled window. Free space stays permanently **below the 150 GiB no-op watermark** (`noop_free_threshold_bytes` = 161,061,273,600), so retention runs every cycle. D: is chronically pressured but held in the ~60–85 GiB band; the recurring FAIL_CLOSED does not free the log bytes it targets on the failing runs.

## 7. Summary

- Restore of the production backup is **proven**: both the off-box bundle and the on-box scheduled snapshot copy cleanly, hash-match their source, pass `integrity_check`/`quick_check`, and preserve row counts and verdicts (stable rows identical).
- **RPO:** off-box ≈ 23 min measured / ≈ 24 h worst-case (daily); on-box scheduled ≈ 9.1 h (stalled — should be hourly).
- **RTO:** ≈ 8–10 s for DB copy + integrity validation (warm cache); operational failover larger and unmeasured.
- **Biggest durability risk:** the on-box "hourly" snapshot is silently skipped by a glob guard that the frequent pre-mutation snapshots keep "fresh", and the health check is masked by the same glob — so the primary fast-restore copy is 9 h stale while all surfaces read green. The off-box daily bundle is the only mechanism currently meeting its own cadence.

## 8. Limits

- Live DB accessed **read-only**; restore tested only against **scratch copies**; production was never overwritten and no writer/task/terminal was stopped or started.
- RTO excludes a **cold** off-box network pull (the G: file was locally materialised) and excludes operational failover (writer quiesce, file swap, farm restart).
- The 4h-vs-1h `PumpMaintenance` cadence discrepancy is reported as an observation; its precise scheduler cause was not isolated within the measurement window.
- Per the orchestrator instruction this task writes **one** evidence file: the retention-lock fix (payload part 2) and threshold reconciliation (part 3) are diagnosed with anchors and a recommended fix but **not implemented**; no git add/commit was performed by this task.
- Scratch restore copies (`restore_offbox.sqlite`, `restore_onbox.sqlite`, ~1.4 GB) were **deleted** at the end of the run.
