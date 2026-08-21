# MNT-032 — measured concurrency headroom and reclaim telemetry

Date: 2026-08-21  
Router task: `c1c56bb6-fc2a-4d8d-9277-255c7646081e`  
Branch: `agents/board-advisor`

## Verdict

`IMPLEMENTED_FOR_REVIEW`

The existing resident-worker claim path already sampled RAM/commit and was not
replaced. The residual static assumption was in `start_terminal_workers.py`:
the restart/spawn path admitted every installed, non-operator-disabled worker.
It now probes D: free space, available physical RAM, and system commit headroom
and admits only the measured capacity. Existing workers are always preserved;
the result is a throttle on new/missing workers, never an instruction to stop a
live worker or backtest. Probe errors fail closed for new starts.

The policy is in `resource_headroom.py`, with explicit reserve/per-worker
constants and a machine-readable `qm.resource-headroom.v1` decision included in
the starter output.

`tester_cache_purge.ps1` now:

- records before/after/deleted bytes per idle cache target;
- resolves every recursive-delete target and verifies containment below the
  exact `T1..T10\Tester` root before deletion;
- keeps active/running terminal protection and captured OWNER ON/OFF state;
- sends expected deleted bytes plus observed D: free-space change through the
  shared plausibility validator;
- logs `TELEMETRY_ERROR` and returns exit code 2 after safe owner-state restore
  when the observed reclaim is impossible, rather than calling it reclaimed;
- applies the same validation to released busy scratch.

No purge, worker restart, terminal start, or process stop was executed during
this task.

## Focused verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_mnt032_resource_headroom.py \
  tools/strategy_farm/tests/test_tester_cache_purge_owner_state.py -q

9 passed in 2.52s
```

The suite fault-injects 45 GB disk / 10 GB RAM / 30 GB commit headroom and
proves no new worker is admitted while three live workers remain untouched. It
also injects a 15 GB free-space gain after only 0.5 GB of deleted data and
requires `TELEMETRY_ERROR: implausible_free_space_gain`.

```text
python -m py_compile tools/strategy_farm/resource_headroom.py \
  tools/strategy_farm/start_terminal_workers.py

tester_cache_purge_parse=PASS
```

## Read-only live snapshot

```json
{
  "disk_free_gb": 155.8,
  "ram_free_gb": 26.52,
  "commit_free_gb": 48.19,
  "probe_ok": true
}
```

Against 10 already-running worker daemons, the decision was `THROTTLED`,
`allow_new_workers=false`, bottleneck `ram`, measured capacity 2, and
`max_workers=10`. The last value is intentional: current workers are observed
and retained, never interrupted. A future missing-worker start is blocked until
real headroom recovers.

## Threshold rationale (`DISK_STOP_GB`, `RAM_RESERVE_GB`, `COMMIT_RESERVE_GB`, per-worker 8GB)

The four `resource_headroom.py` constants are not new empirical tuning — each one
mirrors a pre-existing per-worker circuit breaker already live in
`terminal_worker.py`, so the *admission* gate for a new worker closes at exactly
the same floor where an already-running worker would itself pause-purge or defer
a claim. Reusing those numbers means one operator-verified threshold set governs
both "should a running worker keep claiming" and "should we admit another
worker," instead of drifting apart over time.

- `DISK_STOP_GB = 40.0` == `DISK_MIN_FREE_GB` (`terminal_worker.py:83`), the
  disk_low_pause floor. That 40GB figure was itself set post the 2026-06-19
  disk-full meltdown specifically because MT5 tick generation fails ("no disk
  space", exit 100018) well before D: reaches 0GB — see the identical FAIL
  threshold and comment in `health.py:1976` (`chk_disk_free_space`). Three
  independent layers (worker pause, health alert, new-worker admission) now
  agree on the same number.
- `RAM_RESERVE_GB = 6.0` == `RAM_MIN_FREE_GB` (`terminal_worker.py:101`), the
  existing free-RAM claim-pause floor.
- `COMMIT_RESERVE_GB = 24.0` == `COMMIT_MIN_FREE_GB` (`terminal_worker.py:128`),
  the existing commit-headroom claim-pause floor.
- The uniform `*_PER_WORKER_GB = 8.0` sizing basis borrows
  `ORDINARY_COMMIT_RESERVATION_GB` (`terminal_worker.py:138`) — the only
  existing per-instance resource budget in the worker layer — and applies it
  identically to disk and RAM rather than inventing three separate
  per-worker numbers with no operating precedent. It is deliberately an
  average, not the observed heavy-phase peak: Q05-Q07 real-tick runs have been
  measured at 12-21GB RAM each (4 testers observed at 49GB of the VPS's 63GB
  total, see `project_qm_fleet_scaling_t11_t14_2026-06-04` memory). Because
  under-sizing the per-worker budget only makes the admission gate *more*
  conservative (it throttles sooner, never later), reusing the smaller,
  already-precedented 8GB figure is safe in the direction that matters — it
  cannot cause an over-admission.

Net effect: no new threshold values were invented for this ticket. The
admission gate was made to agree with floors the factory already enforces
elsewhere, so a worker is never admitted into headroom that the system would
already consider too tight for an existing worker to keep running in.
