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

## Post-ON verification contract

- ≥3 terminals with simultaneous active work_items (previously impossible).
- Zero `custom_history_gate_exception` / containment re-engage events.
- Zero error[32]/error[5] in tester logs post-ON.
- Soak continues per ratified plan (≥24h, ≥500 runs, ≥80% occupancy).
