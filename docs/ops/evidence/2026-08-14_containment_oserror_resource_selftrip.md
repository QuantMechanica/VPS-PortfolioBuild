# 2026-08-14 evening: containment self-trip via resource-exhaustion OSError

## Incident

- 18:11:54Z (`recorded_at_utc` in `custom_history_containment_mode.json`):
  fleet containment engaged, reason `custom_history_gate_exception:OSError`,
  source `automatic_stop_condition`.
- Trigger class: `OSError(22, 'Insufficient system resources exist to
  complete the requested service')` (winerror 1450) raised inside the worker
  gate on T1/T7/T10 while 8 concurrent full-history backtests (spawned
  19:13–19:16Z... local 21:13–21:16 — post-reboot recovery wave) saturated
  RAM. Same benign resource class as the 10:04Z MemoryError trip fixed
  earlier today; raw OSError was not on the transient whitelist.
- Effect: with containment engaged, every claim requires the global
  custom-history lease → the whole farm serializes to ONE claim lifecycle.
  Observed: only T8 running (claim 18:53Z, `QM5_20294_XAU_XAG_LOWMAX_D1`
  Q02), 9 workers looping `custom_history_lease_busy`
  (`PermissionError(13)` reading the exclusively-held lease record),
  1026 pending work items, zero work_item updates for >30 min.
- No integrity fact was in question: all recent
  `custom_history_repairs.jsonl` rows are `REPAIRED_VERIFIED` from the
  master tree (last 16:42Z, before the trip); master repair status healthy.

## Evidence

- `D:\QM\strategy_farm\state\custom_history_containment_mode.json`
  (mode_sha256 7aa58d84…, reason `custom_history_gate_exception:OSError`)
- `D:\QM\strategy_farm\logs\terminal_worker_T1.log` line 10483,
  `terminal_worker_T7.log` line 11705, `terminal_worker_T10.log` lines
  11830/12057 (the OSError(22) gate events)
- `terminal_worker_T*.log` tails: `custom_history_lease_busy` loops
- `farm_state.sqlite`: active=1 / pending=1026 at 20:45Z

## Fix (this commit)

`terminal_worker._is_transient_gate_io_error` now classifies Windows
resource-exhaustion OSErrors as transient (defer this claim attempt only,
no fleet stop): winerror ∈ {8 ERROR_NOT_ENOUGH_MEMORY, 14 ERROR_OUTOFMEMORY,
1450 ERROR_NO_SYSTEM_RESOURCES, 1455 ERROR_COMMITMENT_LIMIT} or
errno ENOMEM. Deliberately narrow: unlisted OSErrors (e.g. CRC/device
errors) still engage containment.

Tests: `test_terminal_worker_custom_history_isolation.py` — new
`test_resource_exhaustion_oserror_defers_without_containment`,
`test_enomem_oserror_defers_without_containment`,
`test_unlisted_oserror_still_engages_containment` (15 passed; copy_on_claim
+ master suites 12 passed).

## Recovery sequence (mirrors 2026-08-14 afternoon ceremony)

1. Commit fix + tests + this evidence.
2. `Factory_OFF.ps1` (PS5.1) — drain; workers must restart to load the fix.
3. `custom_history_migration.py release-containment` under OFF quiet
   (standing pair DL-086 + dual audits 3+4).
4. Mint runtime-activation decision, commit decision + sidecar.
5. `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause` (PS5.1).
6. Verify: containment `enabled:false`, concurrent claims ≥2 growing,
   run_results flowing, no re-trip on benign defers.

Ceremony outcomes appended below after execution.

## Ceremony record (appended)

- 20:49Z Factory_OFF #1: workers/terminals drained, managed Codex drain
  FAILED (SYSTEM max-review exec started 20:45Z, lease cap 230 min).
  Bounded wait; exec ended on its own ~21:07Z.
- 21:14Z Factory_OFF #2: FACTORY QUIESCENT.
- 21:15Z stale lease swept (`.stale_t8_pid12908_dead_20260814T211548Z`,
  holder pid dead), orphaned claim be182dfd (QM5_20294 Q02) reset to
  pending, worker-release semantics + claim-ledger retraction.
- 21:16Z release-containment COMMITTED (standing pair DL-086, dual audits
  3+4, mode_sha 24b2ee81…).
- 21:33Z Factory_ON (RTA-2026-08-14-OSERRFIX): mutation committed,
  post-commit evidence PASS (WAL 43/43), 10/10 daemons live. Note: the ON
  argv guard requires backslash-canonical `-File` argv — a forward-slash
  path aborts pre-mutation (decision stays valid).
- 21:41Z dispatch fanned out to 8 concurrent claims (T1–T7, T10).

## Re-trip 21:49Z: master_repair PARTIAL conflates transient copy races

- 21:49:45Z containment re-engaged, reason
  `custom_history_isolation_gate_failure`: T8's gate repair pass reported
  `master_repair PARTIAL` (failed_count=1, already_present=3). The failed
  file `history/GBPAUD.DWX/2022.hcc` exists in the master and was
  REPAIRED_VERIFIED for another terminal in the same second (21:49:40Z,
  sha 293716f3…) — a concurrent-repair copy race, not a vouching failure.
- Fix (second commit tonight): `custom_history_master.repair_missing_archives`
  now classifies each failure (`transient_io`, `exception_type`) via
  `is_transient_repair_io_error` (CustomHistoryMasterError anywhere in the
  chain always wins = non-transient); `custom_history_gate` reports
  `PARTIAL_TRANSIENT_IO` / `ERROR_TRANSIENT_IO` when every failure is
  transient; those statuses defer the claim without engaging containment
  (`_custom_history_gate_fail_is_emergency` unchanged: only ERROR/PARTIAL
  contain). Tests: +2 isolation defers, +1 gate PARTIAL_TRANSIENT_IO,
  +classifier unit tests (31 passed; full custom-history/isolation selection
  80 passed + 1 PRE-EXISTING order-dependent failure
  `test_privatize_fails_closed_without_master_state`, fails identically
  without this change, passes standalone).
- Second release ceremony required (workers have no self-reload).
