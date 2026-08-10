# Ramp-10 fleet serialization — root cause, gate STAT_ONLY fix, governed reload

Date: 2026-08-10 · Author: Claude · Window: `custom_history_variant_a_20260809_ramp_soak`
(OWNER countersigned 2026-08-10T04:43:06Z, receipt sha `a07f3a96…626fdd`, valid to 2026-08-11T04:25Z)

## Symptom

After ramp 10 was set (2026-08-10T06:08:49Z, `custom_history_ramp.json`,
`sequenced_full_fleet_soak`), only ONE terminal ever ran a backtest at a time
(T7 → QM5_20268 done 07:53:30Z → T1 claimed QM5_20192 07:54:52Z). 1131 items
pending. OWNER observed and asked twice ("Derzeit nur auf T7 ein Backtest?").

## Root cause (evidence)

1. `D:\QM\reports\state…\custom_history_containment_mode.json` (recorded
   2026-08-10T06:15:14Z): `enabled:true`, reason
   `custom_history_gate_exception:PermissionError`, source
   `automatic_stop_condition` — containment auto re-engaged six minutes after
   ramp 10, silently re-serializing the fleet through the global lease.
2. Worker logs (`D:\QM\strategy_farm\logs\terminal_worker_T*.log`): T1, T2,
   T6, T9, T10 each logged `custom_history_gate_pause` with
   `PermissionError(13, 'Permission denied')`; T10 additionally a
   `FileNotFoundError(2)` variant.
3. Code path: `custom_history_gate.run_worker_gate` ran
   `audit_history_isolation` over ALL ten terminals on every claim, and
   `collect_variant_a_file_inventory` content-hashed EVERY terminal-private
   archive (`sha256_file`, mt5_history_isolation.py). A running terminal's
   MT5 holds its privatized `.hcc`/`.tkc` write-open (the very fact that
   forced the copy-on-claim amendment), so a concurrent gate's read-open
   raised a sharing violation. `terminal_worker._custom_history_gate`
   escalated any gate exception to fleet-wide emergency containment.
   Conclusion: at ramp 10 the collapse was structural (first gate check
   during any active run re-engaged containment), not transient.
4. The FileNotFoundError variant: enumeration raced a vanishing
   `.copy-on-claim.<pid>.<hex>.tmp` privatization copy.

## Fix — commit `c86699de6` (branch agents/board-advisor)

- `mt5_history_isolation.py`: new `hash_private_terminals` scope. The
  dispatch gate content-hashes only the claiming terminal's private inodes;
  foreign private inodes are verified STAT_ONLY (file_id, size vs manifest,
  nlink==1, cross-terminal alias rejection). Their content stays bound by
  their own claim-time copy-on-claim SHA proof plus the quiescent full
  audits (`verify_archive_hashes=True` keeps FULL hashing). Honest audit
  field: `terminal_private_hash_verification=CLAIMING_TERMINAL_ONLY`.
  Collector skips `.copy-on-claim.` temp files and tolerates
  vanish-mid-scan; genuine deletions remain fail-closed through the
  missing-path synthesis (`MANIFEST_ARCHIVE_FILE_MISSING`).
- `custom_history_gate.py`: passes `hash_private_terminals=(target,)`.
- `terminal_worker.py`: transient IO gate errors (PermissionError /
  FileNotFoundError, including wrapped causes) defer the single claim
  (`custom_history_gate_transient_io`, 30s pause loop) instead of engaging
  fleet-wide containment. All other exceptions keep containment semantics.
- Tests: 7 new regression tests. Focused set 107 passed
  (`frozen_commit_probe` flake re-passed isolated, known class 2026-07-29).

## Governed reload ceremony (all fail-closed steps passed)

1. 21-task map realigned: `QM_StrategyFarm_CodexFleetPacer` re-enabled
   (safe since run_smoke gate+reservation integration, commit 6f0658b28).
2. `Factory_OFF.ps1` clean quiesce — MNT-046 evidence
   `D:\QM\reports\maintenance\factory_off\mnt046_factory_off_quiescence_20260810T082213Z_1316.json`;
   T_Live/FTMO untouched.
3. Stale T1 claim released via production
   `release_stale_claims_for_terminal` (item `9268779a`); dead-holder lease
   (PID 15696 verified dead) archived to the window artifacts.
4. Containment released under quiescence: mode `817830c1…`, enabled:false,
   reason `post_gate_stat_only_fix_c86699de6_quiescent_release_for_ramp10_soak`.
   Ramp receipt intact (limit 10, activation `61c8c72c…`).
5. Preparation renewed (the 2026-08-09 authorization expired 05:47:25Z while
   the countersigned extension window is open):
   `docs/ops/evidence/2026-08-10_factory_preparation_owner_decision_isolation_rampsoak.json`
   — commit `b6135d9c9`, blob `e4fe809e1`, worktree normalized to LF blob
   bytes, pinned sha `ad275c2b…`. Pins repinned in
   `factory_runtime_activation.py`, `Factory_ON.ps1`,
   `maintenance_control.py` (commits `b23a7ce8f`, `31a3ddadb`); template
   rebound (`61b4b2ebe`).
6. Runtime decision minted via the committed fail-closed builder
   (`build_runtime_activation_decision.py`, first use since 08-04 —
   template drift was why prior mints were hand-built):
   `FACTORY_RUNTIME_20260810_RAMPSOAK_GATE_STATONLY_RELOAD`, decision sha
   `a0ceed39…`, OFF-flag sha `226414b9…`, source cohort `61b4b2ebe`,
   committed `397324f15`, standalone validator `authorized:true`, valid to
   2026-08-11T08:30:10Z.
7. `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause` (canonical argv).

## Second collapse class after the first reload (same day)

The 08:36Z Factory_ON with the STAT_ONLY gate proved multi-terminal claims
for the first time (T7/T9/T10 simultaneously active 08:40Z, monitor
SUCCESS). Four minutes later containment re-engaged again — this time via
the FINDINGS path (`custom_history_isolation_gate_failure`, 08:40:34Z), not
an exception: concurrent copy-on-claim privatizations (T7 XAU basket, T4/T9
GDAXI, T10 XAU) shrank hardlink families while other gates were
mid-snapshot. The sequential scan then reported
`ARCHIVE_LINK_COUNT_TOO_LOW` with exactly `actual == minimum-1`
(T1: 679 findings, T2: 540, T3: 561, T4: 169, T6: 311, T8: 510, T9: 316 —
all XAUUSD/GDAXI families, worker logs post-restart offsets verified), and
the worker escalated the gate FAIL to fleet-wide containment.

Fix — commit `8b13cc91f`: `run_worker_gate` re-audits (max 3 attempts,
1.5s apart) when the finding set is exclusively
`ARCHIVE_LINK_COUNT_TOO_LOW`. A consistent second snapshot passes; genuine
deletions raise `MANIFEST_ARCHIVE_FILE_MISSING` (different code — no retry)
or persist across all re-audits (e.g. a deleted rollback link) and remain
fail-closed. 3 regression tests; focused set 48 passed.

Second governed reload: OFF (clean, T_Live/FTMO untouched) → stale claim
`32649a6e` released, lease archived → containment released
(`post_link_count_reaudit_fix_8b13cc91f_quiescent_release_ramp10_soak`) →
runtime decision R3 minted via builder
(`FACTORY_RUNTIME_20260810_RAMPSOAK_GATE_STATONLY_RELOAD_R3`, sha
`8989e27d…`, cohort `8b13cc91f`, authorized:true, valid to
2026-08-11T08:48:21Z) → Factory_ON.

## Post-ON verification contract

- ≥3 terminals with simultaneous active work_items (proven 08:40Z, must
  now hold WITHOUT containment re-engage).
- Zero `custom_history_gate_exception` / containment re-engage events over
  a 1h stability monitor; transient `custom_history_gate_transient_io`
  deferrals and re-audit passes are acceptable by design.
- Zero error[32]/error[5] in tester logs post-ON.
- Soak continues per ratified plan (≥24h, ≥500 runs, ≥80% occupancy).

## Post-ON verification results (R4, 2026-08-10)

Runtime decision R4 `FACTORY_RUNTIME_20260810_RAMPSOAK_GATE_STATONLY_RELOAD_R4`
(sha `e367a768…`, runtime_decision_commit `c41528c51`, valid to
2026-08-11T08:54:52Z) went live after a third Factory_OFF re-finalized the
OFF flag: an aborted ON (benign AgentRouter `state='Running'` health race)
had rewritten it to `OFF_RECOVERY_REQUIRED`; re-running Factory_OFF
preserved the saved 21-task map (Factory_OFF.ps1 lines 566–579). Outcome:

- Milestones ≥3 / ≥5 / ≥8 simultaneously active terminals reached; peak 8
  (T2,T3,T4,T5,T6,T8,T9,T10). HOUR_STABLE: one full hour at ramp 10 with
  containment off, 0 gate FAIL_CLOSED, 0 transient defers post-R4.
- 45 work items completed by 2026-08-10 midday vs ~1/h under the serialized
  regime (source: `farm_state.sqlite` work_items, done since R4-ON).
- Containment mode `D:\QM\strategy_farm\state\custom_history_containment_mode.json`:
  `enabled:false`, reason
  `post_link_count_reaudit_fix_8b13cc91f_quiescent_release_ramp10_soak`.
- Queue at soak start: 1036 Q02 + 24 Q03 + 39 Q04 pending; Q09_NEWS
  59 done / 24 failed / 2 pending (live-book news backfill rides this queue).
- Branch `agents/board-advisor` pushed (through `5964cd9b0`); main
  integration deferred to soak close-out (runbook step 15) — main carries 98
  commits not on this branch, so it is a true merge, not a fast-forward.

Close-out contract (2026-08-11): evaluate the ≥24h soak — ≥500 runs, ≥80%
occupancy in a 4h window, 0 error[32]/error[5], archive-integrity audit
(quiescent FULL hash), before/after error-32 numbers — then rollback-tree
retention decision, migration execution record, main integration.

## Third collapse class — re-audit window vs long privatizations (17:28Z)

Containment re-engaged 2026-08-10T17:28:00Z
(`custom_history_isolation_gate_failure`, mode `ea411b2e…`). T7's gate
recorded 288 findings, exclusively `ARCHIVE_LINK_COUNT_TOO_LOW` with
`actual==minimum-1`, all `ticks/AUDJPY.DWX` + `history/AUDJPY.DWX` families,
staggered by scan order (T2: 11, T3: 25, T4: 37, T5–T9: all 43; T1/T10
zero) — the signature of a single terminal privatizing AUDJPY's 43 archives
file-by-file WHILE each audit pass scanned the fleet. Root cause: one
inventory pass spans many seconds and a large copy-on-claim privatization
runs for minutes, so all three whole-audit retries (8b13cc91f) saw freshly
torn state every time. The 8b13cc91f re-audit assumption ("a consistent
second snapshot passes") only holds for sub-second churn.

Timing note: the privatization started on T1/T10 immediately after their
stale run_smoke reservations (dead holder PIDs 2020/15232, blocking claims
since ~13:25Z/12:19Z) were released at ~17:0xZ — the fleet resumed claiming
AUDJPY-family work and the first large privatization hit the gate window.

Fix — commit `6a1366777`: `reconcile_archive_link_count_findings` in
mt5_history_isolation.py performs per-path instantaneous recounts: for each
flagged family it stats the path across all ten terminals in one tight pass
(microsecond-scale) and clears the finding iff every non-member is a valid
private inode (nlink==1, manifest size) and the members' shared inode
reports exactly `link_count_at_build + member_count` links. Deleted
rollback links, cross-terminal aliases, missing files, and unexplained
deficits keep their findings; reconciliation errors stay fail-closed. Wired
into `run_worker_gate` after the (retained) re-audit loop; result records
`link_count_reconciliation` = CLEARED/REMAINING/ERROR. 8 new regression
tests; focused set 49 passed.

Third governed reload: Factory_OFF (first attempt died at the known
PSModulePath/Get-FileHash trap, flag preserved at OFF_IN_PROGRESS with the
21-task map; re-run with repaired PSModulePath finalized OFF — MNT-046
evidence `mnt046_factory_off_quiescence_20260810T174039Z_10264.json`,
T_Live/FTMO untouched) → stale claims T3/T5 released, dead-holder global
lease (pythonw 16408) + 3 agent-task locks + orchestration lock (PIDs
9876/14440 dead) archived to the window artifacts → containment released
(mode `e722da43…`, reason
`post_link_count_reconciliation_fix_6a1366777_quiescent_release_ramp10_soak`)
→ runtime decision R5 minted via builder:
`FACTORY_RUNTIME_20260810_RAMPSOAK_LINKCOUNT_RECONCILE_R5`, decision sha
`41ad2045…`, flag sha `915ea8a9…`, source cohort `5c5bb6023`, task-map sha
matches pinned `ccfb1611…`, valid to 2026-08-11T17:44:13Z → Factory_ON.

Soak-clock note: the fleet was containment-serialized 17:28Z→~18:0xZ; the
close-out occupancy window must exclude or annotate this span, and the
run_smoke reservation holds (legitimate admission work) count as occupied.
