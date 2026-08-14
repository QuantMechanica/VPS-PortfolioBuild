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
