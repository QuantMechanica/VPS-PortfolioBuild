# Fleet freeze at 4/10 — the headroom governor charged running workers twice

**Date:** 2026-08-21 · **Author:** Claude (Orchestrator, pipeline-watch loop iteration 1)
**Severity:** throughput-critical — 6 of 10 terminals dark while the Q02/Q04 queue held 2100+ items
**Fix commit:** `fix(headroom): credit running workers — the governor froze the fleet at 4/10`
**Introduced by:** MNT-032 (`652f3d3f5`, same day) — the advisory in its own review materialised in production within hours.

## Symptom

`farmctl health` reported `mt5_worker_saturation` FAIL: *4/10 design terminal_worker
capacity alive (T1, T2, T3, T4)*. `QM_StrategyFarm_FactoryWatchdog_15min` was **not**
silent — it tried to heal on every run and failed on every run:

```
17:25:03Z worker_dedupe_heal  workers=3 -> workers_after=4/10        (last successful growth)
17:30:04Z heal_failed  ERROR: dedupe launch made no progress: workers_before=4 workers_after=4
17:35:04Z heal_failed  ... (identical)
17:40 / 17:45 / 17:50 / 17:55 / 18:00 / 18:05 / 18:10  heal_failed
```

Nine consecutive failed heals. The log line named the mechanism ("interactive token
worker heal failed"), which pointed at the CreateProcessAsUser path — a red herring.

## Root cause (measured, not inferred)

`resource_headroom.probe()` reports **free** resources. `concurrency_decision()` turned
each into a per-resource capacity and then used it as an **absolute fleet cap**:

```python
capacities["ram"] = floor((ram_free - RAM_RESERVE_GB) / RAM_PER_WORKER_GB)
resource_cap      = min(installed, *capacities.values())
max_workers       = max(running, resource_cap)
allow_new         = running < max_workers
```

Live values at the time of the freeze:

| quantity | value |
|---|---|
| `ram_free_gb` | 39.75 |
| `RAM_RESERVE_GB` | 6.0 |
| `RAM_PER_WORKER_GB` | 8.0 |
| ⇒ `capacities["ram"]` | `floor(33.75 / 8)` = **4** |
| `running_workers` | **4** |
| ⇒ `max_workers` | `max(4, 4)` = 4 |
| ⇒ `allow_new_workers` | `4 < 4` = **False** |

The four running workers had already consumed their RAM, so they were charged a second
time against the free-RAM figure. `start_terminal_workers.py:137`
(`target = max(len(running), max_workers)`) therefore computed a target equal to the
current count and spawned nothing — a **self-fulfilling freeze**: the fleet stays pinned
wherever it happens to stand, and every heal attempt is a guaranteed no-op.

The freeze is stable in both directions: it would equally have pinned a fleet at 1 or 9.

## Fix

Capacities are what they measure — headroom for **additional** workers:

```python
additional_cap = min(capacities.values())
resource_cap   = min(installed, running + additional_cap)
```

`state` was also decoupled from fleet fullness: it now reports resource **pressure**
(`resource_cap < installed or additional_cap == 0`), so a full fleet on a tight host still
reads `THROTTLED` instead of flipping to a misleading `OPEN`.

The guard's intent is untouched: reserves (`RAM_RESERVE_GB`, `DISK_STOP_GB`,
`COMMIT_RESERVE_GB`) and per-worker sizing are unchanged, and a worker is still never
started without free per-worker headroom right now. The starved case is pinned by test:
12GB free RAM ⇒ `additional_capacity == 0`, `allow_new_workers is False`.

## Verification

- All **6 pre-existing MNT-032 tests pass unchanged** (no test was weakened to fit the fix).
- New regression test `test_running_workers_are_not_charged_twice_against_free_ram`
  pins both directions of the exact live scenario.
- Live decision before fix: `max_workers=4, allow_new=False`; after fix:
  `max_workers=7, additional_capacity=3, allow_new=True`.
- Watchdog triggered once after the fix:
  `18:15:03Z worker_dedupe_heal ... workers_before=4 workers_after=7/10`.
- Fleet confirmed by process scan: **T1–T7 alive** (was T1–T4).
- Next decision at 7 running: `state=OPEN, max_workers=10, additional_capacity=3` —
  the fleet may reach full strength on the following heal as RAM allows.

## Blast radius / rollback

`concurrency_decision` is consumed by `start_terminal_workers.py` (spawn target) and the
purge telemetry path. The change can only ever permit **more** workers than before, never
fewer, and never interrupts a running worker. The real RAM protection remains the
claim-level admission gate (per-claim reservation, unchanged).
Rollback: `git revert` the fix commit — the guard returns to the frozen-cap form.

## Follow-up

`RAM_PER_WORKER_GB = 8.0` mirrors an *ordinary claim* reservation, but a worker **daemon**
is a small Python process; the 8GB is charged at spawn time although the claim gate already
reserves at claim time. That is deliberate conservatism, not a defect — but it means the
fleet will under-fill whenever free RAM is below `6 + 8·(10 − running)`. Worth calibrating
against measured daemon RSS in a later pass.
