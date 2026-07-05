# Evidence: Watchdog Parse Fix + Session Resilience (2026-07-05)

**Tasks:** `4f92571b` (URGENT watchdog 0x800700E0) + `61cf8e02` (session resilience)
**Author:** Claude (claude-sonnet-4-6, orchestration cycle 2026-07-05T13:31Z)

---

## 1. Root Cause — factory_watchdog.ps1 parse error (task 4f92571b)

### Symptom

`QM_StrategyFarm_FactoryWatchdog_15min` LastTaskResult = `0x00000001` continuously
since 2026-07-04T02:30Z. Manual admin run exited 0; scheduled run failed.
`factory_watchdog.jsonl` had no entries between 02:30Z July 4 and the manual run at
11:42Z; all further scheduled runs were silent failures.

### Diagnosis

Running `powershell.exe -NoProfile -ExecutionPolicy Bypass -File factory_watchdog.ps1`
in Windows PowerShell 5.1 produced:

```
Missing closing ')' in expression.
At factory_watchdog.ps1:541 char:44
+ elseif ($factoryEnabled -and $lsmDegraded) {
```

The PS AST parser (`[scriptblock]::Create()`) in PowerShell 7 (pwsh) parsed the file
without error, masking the defect during development.

**Root cause:** Line 548 contained an em-dash character (`—`, U+2014, UTF-8 bytes
`0xE2 0x80 0x94`) inside a double-quoted string:

```powershell
$detail = "...session not confirmed lost — no destructive action taken"
```

When Windows PowerShell 5.1 reads a UTF-8 file **without BOM** using the system
ANSI code page (Windows-1252), byte `0x94` maps to U+201D (RIGHT DOUBLE QUOTATION
MARK `"`). PowerShell treats smart-quotes as string delimiters, so the string was
prematurely terminated at the em-dash, making the remainder of line 548 invalid
syntax. The cascade of parser errors from line 541 onward all stem from this single
encoding mismatch.

### Fix

Replaced the em-dash with a plain ASCII hyphen in factory_watchdog.ps1:

```
- "...session not confirmed lost — no destructive action taken"
+ "...session not confirmed lost - no destructive action taken"
```

All other em-dashes in the file are in comments (ignored by the parser) and were
left unchanged.

**Verification:** `powershell.exe -Command "[Parser]::ParseFile(...)` returns
`PARSE OK`. Scheduled task re-registered; first post-fix run at 2026-07-05T13:39Z
returned `LastTaskResult=0x00000000`, log entry written with `session_lost=false,
lsm_degraded=false, action=realstall_guarded`.

### Rule going forward

Any double-quoted string in PowerShell scripts deployed to Windows PowerShell 5.1
(scheduled tasks using `powershell.exe`) must contain only ASCII characters. Em-dashes
and other non-ASCII Unicode are safe in comments but not in string literals.

---

## 2. NIGHTWATCH stale-read fix — hourly_monitor.ps1 (task 4f92571b)

Added watchdog stale-detection to `hourly_monitor.ps1` (section 3b). The monitor now:
1. Reads the last 20 lines of `factory_watchdog.jsonl` looking for the most-recent
   `action=heartbeat` entry (written at the end of every watchdog cycle).
2. If the heartbeat timestamp is older than 30 minutes, escalates:
   `WATCHDOG-STALE:last_heartbeat=<ts> age=<N>min; watchdog task may be frozen`
3. If no heartbeat found in tail-20, escalates `WATCHDOG-STALE:no_heartbeat_found_in_tail20`.
4. If the log file is missing entirely, escalates `WATCHDOG-STALE:log_missing=<path>`.

This replaces the silent "stale-read" where the hourly monitor would re-emit the same
old `session_lost_no_autologon` action from hours ago without detecting that the watchdog
had stopped cycling.

---

## 3. Session Resilience — weekly hygiene reboot + LSM probe (task 61cf8e02)

### Root cause (LSM resource exhaustion)

The factory spawns and kills `terminal64.exe` hundreds of times per day. Each spawn
allocates kernel desktop-heap objects; when the session is long-running (>7d uptime),
accumulated GDI/user-object handles degrade the Local Session Manager (LSM):

- `qwinsta` returns error 87
- Scheduled tasks start failing with `0x800710E0`
- RDP logins become impossible (`0xC0000142`, `0x800700E0`)

Incidents: 2026-06-11 (full session destroy, reboot required), 2026-07-04 (partial —
qwinsta error 87, task scheduler degraded, watchdog failing).

### Desktop-heap SharedSection (current value)

```
HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems\Windows
  SharedSection=1024,65536,4096
```

| Component | Value | Meaning |
|---|---|---|
| System-wide | 1024 KB | Global shared desktop |
| Interactive session | 65536 KB (64 MB) | Per-desktop heap for session 1 |
| Non-interactive | 4096 KB | Session 0 / service desktops |

The interactive-session value (65536 KB) is already at the standard upper limit for
Windows. Increasing it requires an explicit OWNER decision and takes effect only after
a reboot. **No change recommended at this time** — the weekly hygiene reboot addresses
the accumulated-handle root cause without requiring a registry modification.

### Automation deployed (committed 2707463e9, registered 2026-07-05)

| Task | Principal | Cadence | Purpose |
|---|---|---|---|
| `QM_StrategyFarm_HygieneReboot` | SYSTEM | Saturday 07:00 local | Controlled weekly reboot — purges accumulated kernel objects before LSM degrades |
| `QM_StrategyFarm_LsmHealthProbe` | SYSTEM | Every 6 hours | Probes qwinsta, task results, logon sessions, spawn viability; writes `lsm_health.json` |
| `QM_StrategyFarm_WorkerDedupe` | qm-admin/Interactive | On-demand | Surgical worker-slot fill delegated from SYSTEM watchdog |

**health.py check:** `lsm_session_health` reads `lsm_health.json`; emits WARN on
`verdict=degrading`, FAIL on `verdict=critical`.

Current LSM state (2026-07-05T13:32Z, post-reboot uptime=0d):
```json
{"verdict":"degrading","qwinsta_ok":true,"tasks_failing_count":2,"tasks_checked":3,
 "logon_session_ok":true,"spawn_ok":true,"uptime_days":0}
```

The `tasks_failing_count=2` was caused by the watchdog parse error (now fixed) and
another task; after the watchdog fix and next probe cycle, this is expected to return to
`verdict=ok`.

### Hygiene reboot guards (weekly_hygiene_reboot.ps1)

The reboot only fires when ALL guards pass:
- Day = Saturday (08:00 local trigger, 07:00 guard window 06:00-12:00)
- Uptime >= 5 days
- No `HYGIENE_REBOOT_DISABLED.flag` present
- Debounce: last reboot >= 3 days ago
- Market check: Saturday UTC not a known major-market open window
- No T_Live terminal running (Hard Rule guard)

Kill switch: `New-Item D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag -ItemType File`

Recovery chain after reboot: autologon -> `QM_T_Live_AtLogon` (reconnects live
terminal) -> `QM_StrategyFarm_FactoryON_AtLogon` (restarts factory workers).

---

## 4. Task re-registration

Both watchdog tasks re-registered with SYSTEM/ServiceAccount principal (S4U) —
confirmed "run whether user is logged on or not":

```
QM_StrategyFarm_FactoryWatchdog_15min | SYSTEM/ServiceAccount | LastResult=0x00000000
QM_T_Live_Watchdog                    | SYSTEM/ServiceAccount | LastResult=0x00000000
```

---

## Files changed

| File | Change |
|---|---|
| `tools/strategy_farm/factory_watchdog.ps1` | Fix em-dash -> hyphen in string literal (line 548) |
| `tools/strategy_farm/hourly_monitor.ps1` | Add watchdog stale-read detection (section 3b) |
| `tools/strategy_farm/weekly_hygiene_reboot.ps1` | Pre-existing (committed 2707463e9) |
| `tools/strategy_farm/lsm_health_probe.ps1` | Pre-existing (committed 2707463e9) |
| `tools/strategy_farm/install_hygiene_and_lsm_tasks.ps1` | Pre-existing (committed 2707463e9) |
| `tools/strategy_farm/health.py` | Added `chk_lsm_session_health()` + ALL_CHECKS entry (2026-07-05T13:xx cycle) |
| `tools/strategy_farm/factory_watchdog.ps1` | Multisym guard fix: blocks clean-slate only, not dedupe (task 674f3cbc) |
| `docs/ops/QUOTA_GOVERNOR_AND_FACTORY_RECOVERY_2026-06-21.md` | Added section 6 (dedupe-spawn pattern) |
| `docs/ops/evidence/watchdog_session_resilience_2026-07-05.md` | This doc |

---

## 5. Multisym guard fix — pure worker shortage always uses dedupe (task 674f3cbc)

**Problem (2026-07-04):** Multisym guard at the TOP of the heal-routing block blocked
BOTH clean-slate AND surgical dedupe-spawn paths. When T5 died during T10718 basket EA,
`heal_deferred_active_multisym` fired every 5 minutes for 9+ hours.

**Fix (factory_watchdog.ps1):** Guard now only blocks dispatch-stall + multisym
combination. Pure worker shortage (no stall, no real-stall) always routes to
`QM_StrategyFarm_WorkerDedupe` — safe because dedupe never kills running terminals.

```
if ($dispatchStalled -and $activeMultisymCount -gt 0) → heal_deferred_active_multisym
if ($dispatchStalled -and $activeMultisymCount -eq 0) → FactoryON_AtLogon (clean-slate)
else (pure shortage)                                  → WorkerDedupe (surgical, always)
```

Runbook: `docs/ops/QUOTA_GOVERNOR_AND_FACTORY_RECOVERY_2026-06-21.md` §6.
Parse check: `PARSE_OK` (PS5 parser, confirmed post-edit).
