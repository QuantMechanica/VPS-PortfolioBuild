# 2026-08-14 — Custom-history containment trip: 9 archive files restored, governed release

**Status:** RESOLVED — containment `enabled:false` 06:35:58Z, factory claims resumed 10-wide.
**Operator:** Claude (remote-control session), OWNER countersigned via `!`-executed release scripts.

## What happened

- Overnight/early-morning watchdog kill/respawn cycles ("clean-slate respawn",
  `factory_watchdog.jsonl` 04:20Z/04:50Z/05:00Z/05:05Z) interrupted copy-on-claim
  privatizations. 9 manifest-bound archive files went missing across 5 terminals:
  - T2: `history/GBPNZD.DWX/2022.hcc`
  - T3: `history/EURAUD.DWX/2022.hcc`, `history/NZDJPY.DWX/2022.hcc`
  - T5: `history/CADCHF.DWX/2022.hcc`, `history/WS30.DWX/2022.hcc`
  - T7: `history/EURGBP.DWX/2022.hcc`, `history/EURNZD.DWX/2019.hcc`, `history/NZDCAD.DWX/2019.hcc`
  - T9: `history/GBPAUD.DWX/2022.hcc`
- The Variant-A isolation gate found the gaps (`MANIFEST_ARCHIVE_FILE_MISSING`),
  fail-closed fleet-wide; containment auto-engaged
  (`custom_history_isolation_gate_failure`, `automatic_stop_condition`, 05:10:19Z).
  Result: 1021 pending / 0 active, dispatcher idle. Same failure class as the
  2026-08-13 T8 incident (3 files), wider blast radius.
- Secondary damage: orphaned `pump_task.lock` (holder PID dead; pump had been
  scheduler-killed after a 13-min run — known open "Pump-Cap-Escape" item).
- T_Live and FTMO terminals were untouched throughout.

## Recovery

1. All 9 files restored from the canonical source (T1, = manifest `source_custom`),
   sha256-verified against the owner-approved manifest before AND after copy,
   atomic rename. Evidence (failures=0):
   `D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\restore_evidence_20260814T051425Z.json`
2. Fleet re-scan vs manifest (3946 files x 10 terminals): **no missing archive
   files anywhere**.
3. Orphaned `pump_task.lock` deleted after verifying the recorded holder PID dead.
4. Governed release: `custom_history_migration.py release-containment` with the
   still-open OWNER recovery window `owner_window_receipt_t8_restore.json`
   (open until 08:03:32Z, same failure class/lineage) and registered dual audits
   3+4. Sequenced by
   `D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\release_and_resume_20260814.py`
   (OWNER-executed via `!`).
5. Release-race mechanics (important for next time): with containment engaged the
   global custom-history lease is mandatory and each claim holds it for the FULL
   backtest run — the fleet serializes to one terminal and `release-containment`
   (requires a quiet lease) loses every inter-run gap. Fix: a temporary bare
   `FACTORY_OFF.flag` (claim pause only; workers alive; active run finishes;
   watchdog stands down; NOT a Factory_OFF.ps1 ceremony, no runtime-activation
   decision consumed) quiets the lease to sub-second flickers; the release then
   lands. Flag deleted automatically afterwards.

## Timeline (UTC)

- 03:10–04:20 — watchdog respawn cycles kill workers (T5/T10 at 03:10, T1–T3/T6–T9 at 04:20)
- 04:50–05:05 — repeated `healed_via_factoryon` heal loop, dispatch stalled (0 active, 1021 pending)
- 05:10:19 — containment auto-engaged (`custom_history_isolation_gate_failure`)
- 05:14:25 — 9 files restored + verified (failures=0); fleet re-scan clean
- ~05:39 — worker gates pass again; T7 claims (serialized 1-wide by containment lease)
- 06:15–06:35 — temporary FACTORY_OFF.flag claim pause; lease quiets after active run
- 06:35:58 — governed release lands: containment `enabled:false`; flag removed; claims resume

## Follow-ups (dispatched to day shift)

1. **Privatization crash-safety** — copy-on-claim must never leave a
   delete-before-replace window; a killed worker must leave either the family
   file or the private copy, never neither. (Codex inbox task.)
2. **Pump scheduler-kill / cap escape** — pump exceeded its execution window,
   got killed (exit 0x800710E0), left an orphan lock. (Known marathon item.)
3. **Watchdog kill-loop root cause** — "clean-slate respawn" killed workers
   mid-privatization; respawn heals must drain or exclude workers holding the
   custom-history lease.
