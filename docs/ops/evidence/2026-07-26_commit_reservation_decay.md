# Commit-reservation decay against measured usage — 2026-07-26 (Claude)

OWNER directive after the starvation incident: implement the reservation that decays
with measured consumption instead of a flat hold.

## The problem, stated precisely

A claim becomes visible in SQLite before its child process has allocated anything, so
without a reservation every worker reads the same unchanged OS headroom and they all
admit work into the same gap. The reservation closes that race. But the OS commit
measurement **already contains** whatever a job has actually allocated, so continuing to
reserve its full expected peak double-counts the moment it starts growing.

Both failure modes are real and were both observed today:

| window | behaviour | observed failure |
|---|---|---|
| 300 s flat (original) | expires while a multisym is still growing | 17:45 — jobs admitted into the balloon phase, pagefile storm, workers killed |
| 3600 s flat (`d88a89392`) | double-counts 44 GB for an hour | 18:49 — effective headroom 20.4 GB against 64.5 GB real, whole fleet pinned, no work admitted at all (reverted `347859ad3`) |

## The fix (`d2a19449f`, logging follow-up `5f5d294c8`)

```
reservation = max(0, expected_peak - measured_subtree_private_bytes)
```

- **Measurement**: `_process_private_snapshot()` — Toolhelp32 process enumeration plus
  `GetProcessMemoryInfo` (`PrivateUsage`, i.e. private commit, the same quantity the
  headroom probe reports) through ctypes. Cached 3 s. **8 ms cold, 0.4 µs cached**, versus
  hundreds of ms for `farmctl`'s PowerShell probes — usable in the per-poll admission path.
- **Subtree walk**: from the payload `pid` down a children map built from every process's
  parent id, not from live parent links. Phase drivers routinely leave a `run_smoke`/pwsh
  child running after their Python parent exits; Windows keeps the dead parent's id in the
  child's PPID field, so the lineage stays discoverable. Verified live: the 26 GB
  `metatester64` sits three levels below the recorded pid
  (`metatester64 ← terminal64 ← pwsh ← python`).
- **Fail-safe semantics**: probe failure or a pid that cannot be parsed returns `None` →
  the **full** reservation is kept (never assume zero usage). A lineage with no live
  process returns `inf` → reservation drops to 0 (nothing left to grow into). No pid yet →
  full reservation, which is exactly the launch race the mechanism exists for.
- **Windows**: multisym 3600 s (its balloon phase), ordinary unchanged at 300 s. The long
  window is only safe *because* of the decay — a flat hold over the same window is what
  starved the fleet.
- **Observability**: the logged `commit_headroom_low_pause` event now carries
  `commit_reservation_detail` — per claim the expected peak, the measured usage and the
  residual. The previous failure was silent starvation that looked identical to a busy
  fleet; this makes the arithmetic readable in the field.

## Tests

`tools/strategy_farm/tests/test_commit_reservation_decay.py` — 13 cases: unspawned job
reserves its full peak; decay by measured usage; job at/above peak reserves nothing (with
an explicit assertion that 64.5 GB of real headroom stays available, i.e. the incident
cannot recur); probe failure stays conservative; vanished lineage releases; per-lineage
windows; expiry; and the incident's exact shape asserted on the admission verdict.
Together with the existing atomic-claim suite: **64 passed**.

## Live verification

Deployed by worker restart 19:07 / 19:08 (restart does not kill running backtests — a
worker adopts an active claim whose process tree is alive).

Decay observed on the live fleet within a minute of deploy, on the same job that caused
the incident:

| time | QM5_13059 measured | resulting reservation |
|---|---|---|
| 19:07 | 1.32 GB (between neighborhood param points) | ~42.7 GB held — correct, it is about to spawn another tester |
| 19:08 | **30.11 GB** (tester at peak) | ~13.9 GB held — the flat rule would still have held 44 GB |

At 19:08, 7 of 9 workers held claims and were working; before the revert, all nine were
pinned. Aggregate at one sample: 5 active reservations totalling 43.9 GB, where a flat
rule would have reserved 44 + 4×8 = 76 GB.

Note the two guards are independent and measure different things: commit headroom (58.6 GB
at 19:08) includes the 60 GB pagefile, while free **physical** RAM was 2.3 GB. The RAM
floor (`RAM_MIN_FREE_GB` 4.0) is the operative brake in that regime, not the commit gate.
That is pre-existing behaviour, unchanged here, and it is the reason the memory-capacity
question in ticket `213aa9c3` still stands on its own.

## Exit tracer for the silent-death defect (`3455bcf2b`, diagnostic only)

Workers kept vanishing during the observation window (T4/T7 at 19:10) with a resource-pause
event as their last line and an empty stderr. That is **not** this change: the ctypes probe
is wrapped in a blanket `try/except` returning empty maps, no traceback ever appeared, and
the identical signature predates every change tonight (T4/T9/T10 at 17:45).

To stop guessing, `main()` now installs an atexit + signal tracer emitting `worker_exit`,
plus a `worker_start` line for lifetime correlation. Windows runs neither handler on
`TerminateProcess`, so the line's presence classifies the death. **Validated in both
directions before trusting it:**

| case | result |
|---|---|
| orderly exit | `{"event": "worker_exit", "reason": "atexit", ...}` emitted |
| `Stop-Process -Force` (TerminateProcess) | no line — silence confirmed |

New lead for ticket `4e8bcf47`: `QM_StrategyFarm_WorkerDedupe` last ran at **19:10:10**,
the two deaths fell in 19:09–19:10. Its action is
`start_terminal_workers.py --dedupe`, whose only kill path fires when `_scan_running_workers()`
returns more than one pid for the same terminal — worth auditing against the named-mutex
guard, since every manual run tonight reported `stopped_duplicates: {}`.

## Two verdicts the tracer and the task log delivered the same evening

**1. The deaths are external hard kills.** T4 died between 19:20:03 and 19:20:52 with
`worker_start` twice in its log and `worker_exit` **zero** times, empty stderr. The tracer
is proven to fire on orderly exit, and `terminal_worker.py` contains no `os._exit`, no
`os.abort` and no self-termination path — the stalldump watcher only writes tracebacks. So
the process was terminated from outside. None of the known factory tooling can do it:
`_stop_pid()` in `start_terminal_workers.py` is a hardcoded no-op (`return False`,
deliberately fail-closed since a bare pid is not a safe termination authority),
`WorkerDedupe` never executes (below), `Factory_OFF` was not running. Windows logged no
error, no WER entry and has no ResourceExhaustionDetector channel here. Leading remaining
hypothesis: a kernel-level termination under commit exhaustion, which would produce
exactly this signature. **Process Termination auditing enabled** to settle it —
`auditpol /set /subcategory:"Process Termination" /success:enable`; Security event 4689
then carries the exit status. Revert with `/success:disable` when the question is closed.

**2. Factory self-healing has been dead since 17:33 (ticket `7abd518a`, priority 95).**
`QM_StrategyFarm_WorkerDedupe` executed at 16:50, 17:00, 17:10, 17:20 and 17:30:26 and
never again — the session handover was 17:33. Since then every trigger logs event 110
(launched) then 325 (queued), never 200 (action started): 22 attempts, 5 executions, all
before the handover. The discriminator is the principal's `LogonType`, verified across the
QM task set — `ServiceAccount`/SYSTEM tasks and the one `S4U` task all run with rc=0, while
**every** `Interactive` task returns `0x800710E0`. Seven are dead this way, including
`QM_Live_MT5_SessionSupervisor` and `QM_T_Live_AtLogon`.

This is critical because `factory_watchdog.ps1` states in its own header that it runs as
SYSTEM and must never spawn workers directly (session-0 children die 0xC0000142), so **all**
healing is delegated by `Start-ScheduledTask` to exactly that dead class. Every heal it
attempted tonight was a silent no-op — which is what `workers_before=6 workers_after=6`
was telling us. It also corrects my earlier diagnosis in ticket `29e1534a`: during the
00:27–06:36 outage the live supervisor was not dying each cycle, its relaunches were being
queued.

Tried and did not help: `schtasks /end` on the stuck instance then `/run`; re-registering
the task XML. A logoff/logon would restore the binding but is **unsafe** — T_Live's
terminal64 (pid 16388) runs in this session, so a logoff kills live trading.

## Interim mitigation running (`interactive_worker_keeper.py`)

Because the self-healing path is dead and a logoff is not an option while T_Live lives in
this session, a stopgap keeper now runs detached in the interactive factory session
(pid 1584, session 3): every 60 s it fills missing worker slots via the same idempotent
`start_terminal_workers.py --dedupe` the dead task would have called. It does nothing while
`FACTORY_OFF.flag` exists, and a failed process probe is treated as "unknown" rather than
"nothing running", so a transient error cannot make it spawn into a healthy fleet. Log:
`D:\QM\strategy_farm\logs\interactive_worker_keeper.log`.

**Acceptance-tested, not assumed** (the mistake made earlier tonight was declaring a change
proven on two minutes of silence). T10's worker was deliberately killed at 17:27:53Z; the
keeper logged `respawning missing=["T10"]` at 17:28:22Z and the replacement (pid 8080) was
up at 17:28:25Z — **32 seconds from kill to restored fleet**, with the log lines to show
it. Note the keeper is silent while the fleet is complete, so silence in its log means
"nothing to do", not "not running".

This is a substitute, not the fix — delete it when ticket `7abd518a` lands. Stop it with:

```powershell
Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" |
  Where-Object { $_.CommandLine -match 'interactive_worker_keeper' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
```

Note it dies with the session, exactly like the factory it serves.

## Throughput was not harmed

Since 19:00 local: 5 completions (3 PASS, 2 FAIL, **zero INFRA_FAIL**) in 14 minutes,
against a daytime rate of 10–20 per hour. The fleet pauses on the real RAM floor now, and
still clears work at the day's normal pace.

## What this does not solve

The box remains undersized for a 26 GB multisym plus several 8-11 GB ordinary jobs
(ticket `213aa9c3`), and workers still die silently when physical RAM is exhausted rather
than idling through it (ticket `4e8bcf47`). The decay stops the admission arithmetic from
*causing* either, but it cannot make 63 GB of RAM into more.
