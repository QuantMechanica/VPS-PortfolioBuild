# Live MT5 dual-outage independent forensics — Codex

Date: 2026-08-06  
Router task: `148b181a-8817-40c4-bcde-76fd40d66866`  
Scope: T_Live read-only forensics; no terminal process, AutoTrading state, or live profile was changed.

## Q-A independence seal

This section was produced without opening or reading the parallel analyst artifact
`docs/ops/evidence/2026-08-06_live_mt5_dual_outage_forensics.md`. The file was visible as an
untracked path in `git status`, but its contents and metadata were deliberately not inspected.
This document is being committed before any cross-review.

## Verdict

The initiating event is established: Windows suffered an unclean restart at 03:53 local. Both
MT5 processes disappeared with the host. The prolonged dual outage was then caused by three
independent recovery-path failures:

1. The DXZ logon launcher started 34 seconds after OS start and returned launcher code 2 after
   2.99 seconds. The exact fail-closed branch is **NOT ESTABLISHED**, because the launcher emitted
   no durable per-invocation record. A transient boot-window CIM/WMI process-inventory failure is
   plausible and is consistent with the launch timing and known later occurrences, but it is not
   proven for this invocation.
2. FTMO's logon launcher completed with code 0 while the then-baked contract was `PARKED`; the
   watchdog consequently treated FTMO absence as compliant and never requested its recovery.
   This was contract behavior, not evidence that the FTMO terminal had survived.
3. The supposed resident session supervisor completed 20 separate instances normally instead of
   remaining resident. In parallel, a pre-existing task-definition drift made the hardened RunEx
   recovery contract fail closed, so the SYSTEM watchdog could not establish a scheduler-owned
   resident supervisor. It repeatedly fell back to recording the block; the legacy watchdog's
   direct demand starts produced more short-lived supervisor instances but no durable recovery.

The outage was therefore not a single launcher bug. The reboot exposed an observability hole, an
FTMO expected-state mismatch, and a broken supervisor/task contract at the same time.

## Established timeline

All local times below are Europe/Berlin (UTC+02); JSONL timestamps are retained in UTC where shown.

| Local time | Evidence | Finding |
|---|---|---|
| 03:52:37 | System Event 6008 | Previous shutdown was unexpected. |
| 03:53:07 | Kernel-General Event 12 | Windows OS start (`2026-08-06T01:53:07.500Z`). |
| 03:53:09 | Kernel-Power Event 41 | Host rebooted without a clean shutdown. |
| 03:53:41.670 | TaskScheduler Events 119/129/100/200 | `QM_T_Live_AtLogon` launched as `qm-admin`, PowerShell PID 8852. |
| 03:53:44.659 | TaskScheduler Events 201/102 | DXZ action completed with `2147942402` = `0x80070002`, the Task Scheduler representation of process exit code 2. |
| 03:53:47 / 01:53:47Z | `live_uptime_watchdog.jsonl` line 17181 | Exact process probe: both DXZ and FTMO absent; target session 1 Active; recovery task contract false. |
| 03:53:56–03:53:57 | TaskScheduler history | `QM_FTMO_AtLogon` ran and returned 0 under the then-current `PARKED` contract. |
| 03:54:10–03:54:22 | TaskScheduler history | Logon-triggered session supervisor ran for 11.318 seconds and completed normally. |
| 03:55:47 / 01:55:47Z | JSONL line 17183 | Supervisor heartbeat stale; RunEx start blocked by three task-contract errors. |
| 04:00–06:15 | TaskScheduler history | Ten time-triggered and nine demand-triggered supervisor runs completed; none stayed resident. |
| 06:25:05 | TaskScheduler history | Demand-triggered supervisor PID 11280 started and remained resident. |
| approximately 06:29 / 04:29Z | Watchdog JSONL | First watchdog sample with both replacement terminal processes present: DXZ PID 9872, FTMO PID 10400. This establishes recovery, not who launched them. |
| 07:03:58–07:03:59 | TaskScheduler Event 140 | `qm-admin` reconciled the three live task definitions. |
| approximately 07:04 / 05:04Z | Watchdog JSONL | Recovery contract true and PID 11280 first recognized as scheduler-owned. |

Task Scheduler recorded 20 completed supervisor actions before the surviving instance: one logon,
ten time-triggered, and nine demand-triggered. Durations were 11.318–42.133 seconds (mean 17.428
seconds); every action completion record carried result 0. This is one-cycle-equivalent behavior,
not a crash signature. The historical action arguments/task XML are no longer recoverable from the
current task file: the definition was overwritten at 07:03, TaskScheduler's retained Event 200
records omit arguments, Security 4688/Sysmon evidence is unavailable, and the PowerShell logs have
already wrapped past the outage window. Whether the historical action contained `-Once`, the source
was transiently modified, or another normal-exit path was involved is therefore **NOT ESTABLISHED**.

## Recovery-contract drift

The watchdog's append-only records repeatedly name the same three blockers:

- `QM_T_Live_AtLogon:allow_demand_start`
- `QM_FTMO_AtLogon:allow_demand_start`
- `QM_Live_MT5_SessionSupervisor:trigger_count=2`

The combination is present by `2026-07-26T16:02:48Z`, more than ten days before this reboot. It was
not created by the 2026-08-06 crash. The extra supervisor trigger explains the 15-minute scheduled
starts. `AllowDemandStart=true` on the two one-shot launchers violated the hardened design because a
normal InteractiveToken demand start may queue in a disconnected RDP session. The watchdog correctly
refused to use RunEx while the task contract was unauthenticated.

The canonical installer expects one logon trigger for each launcher and the supervisor, disallows
demand start for the one-shot launchers, allows it only for the resident supervisor, and pins the
resident/restart settings. The actor and command that introduced the host drift are **NOT
ESTABLISHED**: the TaskScheduler audit log no longer retains the July registration event. Event 140
does establish that `qm-admin` performed the 07:03 repair, but it does not identify the earlier drift
origin.

## DXZ launcher exit-2 classification

The invocation definitely returned code 2, but a code-only record cannot select among the launcher's
fail-closed branches: wrong context, mutex construction failure, unknown process inventory,
duplicate target process, missing contract files, profile-verifier failure, configuration pin
failure, or final inventory uncertainty. The task principal and active session eliminate neither all
context failures nor the later branches. The post-reboot exact probe at 03:53:47 showed both targets
absent, but it occurred after the failed launcher and cannot reconstruct the launcher's earlier CIM
result.

Boot-window CIM uncertainty is the leading hypothesis, not a finding:

- the launcher began only 34.17 seconds after OS start;
- its first exact inventory probe calls `Get-CimInstance Win32_Process` once and exits 2 immediately
  on either a CIM exception or any unreadable `terminal64.exe` path;
- the append-only watchdog has independently observed
  `one_or_more_terminal64_paths_unreadable`, including at `2026-08-06T03:35:47Z`.

That later observation proves the failure mode exists on this host, but not that it occurred at
03:53:41. Durable branch-level launch logging is required to close this gap on the next incident.

## Durable hardening proposal

1. Both `T_Live_ON.ps1` and `FTMO_ON.ps1` must append exactly one JSON line for every exit path to
   `D:\QM\reports\state\live_launcher_events.jsonl`. The record should include UTC time, launcher,
   PID, identity/session when available, exit code, stable reason, boot age, probe attempt count,
   probe errors, and observed exact-path PIDs. Logging is best-effort and must never turn an unknown
   inventory into permission to launch.
2. During a bounded early-boot window only, an unknown CIM inventory should be retried with bounded
   backoff before the existing fail-closed exit. The proposed bound is three probes over no more than
   15 seconds when OS uptime is at most ten minutes. A positive duplicate/wrong-path signal is never
   retried into absence, and exhaustion still exits 2. Outside the boot window behavior remains a
   single fail-closed probe.
3. Tests must reject bare launcher exits outside the centralized completion function and require a
   non-empty stable reason for every completion. Parser/static contract tests must cover both files.
4. The installer/verifier must continue enforcing one trigger per task, demand-start disabled for
   the two one-shots, and demand-start enabled only for the authenticated resident supervisor.

## Safe end-to-end recovery test design — not executed

This design touches only the supervisor process. It must never stop either terminal or request a
reboot.

1. Preconditions: OWNER-approved maintenance window; no maintenance flag; watchdog recovery task
   contract ready; exactly one DXZ and one FTMO exact-path process in the target `qm-admin` session;
   record both terminal PIDs, creation times, executable hashes, account/profile state, and the sole
   scheduler-owned supervisor engine PID.
2. Reconfirm through Task Scheduler COM that the candidate PID belongs to the single running
   `QM_Live_MT5_SessionSupervisor` instance and that its command line points to the canonical
   supervisor script. Abort on any ambiguity.
3. Stop **only that PowerShell supervisor PID**. Do not stop a scheduled task, either `terminal64.exe`,
   a Windows session, or the watchdog.
4. Observe the next watchdog cycle and its RunEx result. Pass only if a different scheduler-owned
   supervisor PID appears in the same session with a matching fresh heartbeat inside the bounded
   recovery window.
5. Re-read the two terminal PIDs and creation times. They must be byte-for-byte unchanged; there must
   be no reboot request and no launcher record claiming a terminal launch. Any terminal PID change,
   task-contract drift, duplicate, unknown inventory, or timeout is a fail-closed test failure.

This test was deliberately **NOT EXECUTED** during Q-A. No live terminal or supervisor process was
stopped.

## Evidence sources and limitations

- Windows System log: Events 12, 41, 6005, 6008.
- `Microsoft-Windows-TaskScheduler/Operational`: live task launch/complete and definition-update
  records.
- `D:\QM\reports\state\live_uptime_watchdog.jsonl` (append-only).
- `D:\QM\reports\state\live_supervisor_watchdog.log` (append-only legacy watchdog log).
- Current scheduled task definitions and canonical scripts at `C:\QM\repo`.
- Git history for the live installer, supervisor, watchdog, and launchers.

Limitations are explicit: no contemporaneous launcher journal existed; historical task XML/action
arguments were overwritten; no Security 4688 or Sysmon process-creation evidence was available; and
PowerShell event logs had wrapped beyond the incident window. Claims above are separated into
established fact, bounded inference, and **NOT ESTABLISHED** attribution accordingly.

## Q-B cross-review after the independence seal

After commit `cc6965ac6` sealed Q-A, the parallel Claude report was opened. The two independent
reports agree on the reboot, exact DXZ exit-2 interval, FTMO's then-`PARKED` behavior, the three
recovery-contract blockers, the repeated short supervisor actions, and the missing launcher log as
an incident-level observability defect.

The material differences are confidence boundaries, not contradictory host facts:

- Both reports identify boot-window CIM uncertainty as the leading DXZ hypothesis. Neither has a
  contemporaneous branch record, so this report retains **NOT ESTABLISHED** rather than promoting
  the hypothesis to root cause.
- The parallel report left the supervisor death loop open. This report additionally quantified all
  20 completed actions and proved their action result was zero, but retained **NOT ESTABLISHED** for
  the precise normal-exit path because historical arguments/source state are gone.
- The parallel report hypothesized that the July redundancy layer introduced the task drift. The
  retained audit window cannot identify that actor or command, so this report records only that the
  drift existed by 2026-07-26 and predates the crash.

The parallel report's manual-recovery claim was independently corroborated after the seal: both
surviving terminal processes have parent PID 7024, `C:\Windows\Explorer.EXE`, in session 1. DXZ PID
9872 was created at 06:25:14 and FTMO PID 10400 at 06:25:16. That evidence is consistent with an
interactive OWNER start and rules out either hardened launcher as their direct parent.

## Q-C implemented hardening

The proposal above is now implemented in both launchers:

- Every script-controlled completion routes through one centralized function carrying a stable
  reason and exit code. There are no bare numeric `exit` statements outside that function.
- Each completion appends one compact JSON record to
  `D:\QM\reports\state\live_launcher_events.jsonl`. A separate global mutex serializes DXZ and FTMO
  writers. Records include launcher/script identity, process/user/session, code/reason, boot age,
  invocation duration, every process-probe attempt, matched exact-path PIDs, and branch details.
- An unknown process inventory inside the first ten minutes after Windows boot receives at most
  three total probes with 2-second then 4-second backoff. A known result returns immediately; a
  duplicate remains a duplicate; exhaustion remains exit 2. Outside that boot window the original
  single-probe fail-closed behavior remains.
- Windows PowerShell 5.1 compatibility is explicit: boot age uses `Environment.TickCount`, not the
  unavailable .NET Core `TickCount64`. A negative long-uptime wrap disables retries safely.

Files changed:

- `tools/strategy_farm/T_Live_ON.ps1`
- `tools/strategy_farm/FTMO_ON.ps1`
- `tools/strategy_farm/tests/test_live_uptime_watchdog_static.py`

## Q-D verification

- Windows PowerShell 5.1 parser: PASS for both launchers.
- Focused pytest: 39 PASS across the live watchdog, RunEx, silent-failure, and alarm suites.
- Static termination contract: PASS; each launcher contains only centralized `exit $Code`, and all
  completion calls carry `-Reason`.
- Static retry contract: PASS; three-probe/ten-minute/2+4-second bounds and immediate known-result
  return are asserted for both launchers.
- Safe runtime journal check: both launchers were invoked only with their deliberately unsupported
  `-Force` switch, which exits before any terminal inventory or launch path. DXZ and FTMO each
  returned 2 and the final-code check appended `force_unsupported` records at
  `2026-08-06T07:11:50.214Z` and `2026-08-06T07:11:55.903Z` respectively. The records correctly
  captured the headless harness identity/session (`NT AUTHORITY\\SYSTEM`, session 0), script paths,
  boot age, and empty probe lists.
- Terminal non-interference check: exact snapshots before and after that runtime check were equal.
  DXZ remained PID 9872, creation 06:25:14; FTMO remained PID 10400, creation 06:25:16. No terminal
  process was started, stopped, or replaced.

The supervisor-kill RunEx design remains deliberately unexecuted. Verification above did not stop
the supervisor, invoke a reboot, toggle AutoTrading, or mutate a live MT5 profile.
