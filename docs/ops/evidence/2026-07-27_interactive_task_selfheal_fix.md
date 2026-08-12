# Dead self-healing — interactive scheduled-task queue death (census rank 10)

Date/time: 2026-07-27 ~13:30–14:00 UTC
Author: Claude
Scope: census loose-end rank 10 — eight interactive scheduled jobs stuck at
`0x800710E0`; the factory's self-heal path delegates to this class.
Constraints honored: no `Factory_OFF/ON`, no reboot/logoff/tscon, T_Live untouched,
no work-item requeue/bulk-mutate, no claim-path change. All fixes committed with
explicit pathspecs.

Related: `docs/ops/evidence/2026-07-27_factory_loose_ends_census.md` (rank 10);
MEMORY `project_qm_interactive_task_queue_death_2026-07-26`.

---

## 1. Mechanism — ESTABLISHED

**Root cause: the eight tasks are `LogonType=InteractiveToken` and the only qm-admin
logon session is `Disconnected`, so Task Scheduler queues them forever.**

Primary evidence:

- Session state (`qwinsta`): session `3` (qm-admin) is `Disc` (Disconnected); the
  console (session 2) has no user; no other interactive qm-admin session exists.
  This session is where the factory + T_Live run; I am running inside it (session 3).
- Task definition: `QM_WorkItemLogPruner_Daily_0310.xml` line 17
  `<LogonType>InteractiveToken</LogonType>` (the whole affected set reads
  `LogonType=Interactive` via `Get-ScheduledTask`).
- Operational events for an affected task (`QM_Live_MT5_SessionSupervisor`, 8
  consecutive triggers 14:55–15:30Z): each is `110` (task launched) immediately
  followed by `325` (**queued**), and **never** `200` (action started).
  `LastTaskResult = 0x800710E0`.
- Contrast — a working task of each other principal:
  - `QM_StrategyFarm_Tick_5min` (**S4U**): `100/200` started → `201/102` completed.
  - `QM_StrategyFarm_CodexOrchestration_15min` (**SYSTEM**): `100/200` → `201/102`.
  - Their occasional `0x800710E0` is a **different** phenomenon: event `322`
    ("did not launch because an instance … is already running") — instance overlap,
    not a queued refusal. Do not conflate `322`(overlap) with `325`(interactive queue).

**Why `InteractiveToken` queues while S4U/SYSTEM run:** an InteractiveToken action
requires the scheduler to obtain an interactive token from an **active** session.
After the 2026-07-26 17:33 session handover (Windows session-arbitration replaced the
connected qm-admin session with a disconnected one) the session is `Disc`, and
`QM_TSCon_Console_OnDisconnect` is **Disabled** (verified) so nothing reconnects it to
the console. S4U and SYSTEM (ServiceAccount) actions run in session 0 and need no
interactive token, so they are unaffected. `0x800710E0`
(ERROR_OPERATION_IN_PROGRESS) is the queued/pending state, not a crash.

The prior memory's discriminator ("Interactive queues, S4U/SYSTEM run") is corroborated;
its remedy framing ("anything not needing a desktop → SYSTEM") is **too optimistic** —
see §2.

---

## 2. Per-task disposition (the crux: what actually needs the interactive session)

"Needs interactive" is transitive: a headless launcher that spawns `terminal64` (GUI)
or reads a per-user DPAPI credential or the `G:` Google-Drive mount cannot run in
session 0 even though its own process is headless.

| # | Task | Action | Blocking dependency | Verdict |
|---|---|---|---|---|
| 1 | `QM_WorkItemLogPruner_Daily_0310` | `prune_workitem_logs.py` | none — local D: SQLite + `*.log` deletes only | **ACCIDENT → FIXED (SYSTEM)** |
| 2 | `QM_StrategyFarm_AgyGovernor` | `agy_governor.py` → `agy_quota.py` | **DPAPI**: `CredReadW('gemini:antigravity')` (`agy_quota.py:55-61`); code comment `agy_governor.py:13-16` states SYSTEM/S4U cannot decrypt | interactive/Password — OWNER |
| 3 | `QM_StrategyFarm_CodexFleetPacer` | `codex_fleet_pacer.py` | **desktop (transitive)**: spawned codex runs `run_smoke → terminal64` (installer header `install_codex_fleet_pacer_scheduled_task.ps1:2-3`) | genuinely interactive |
| 4 | `QM_StrategyFarm_GeminiOrchestration_15min` | `run_agent_orchestration_task.py --agent gemini` | **G: mount** (`run_agent_orchestration_task.py:152-154,351`) + agy DPAPI creds | genuinely interactive |
| 5 | `QM_StrategyFarm_MailboxSourceIntake_Daily` | `mailbox_source_intake.py` | analyst uses **codex + agy** (DPAPI); installer header `install_mailbox_source_intake_task.ps1:4-6` | genuinely interactive |
| 6 | `QM_StrategyFarm_WorkerDedupe` | `start_terminal_workers.py --dedupe` | **desktop**: spawns factory `terminal64` GUIs (0xC0000142 if session 0) | interactive — **superseded** (see §4) |
| 7 | `QM_Live_MT5_SessionSupervisor` | `Live_MT5_SessionSupervisor.ps1` | **desktop + T_Live** live GUI terminal | interactive — T_Live, do not touch |
| 8 | `QM_T_Live_AtLogon` | `T_Live_ON.ps1` | **desktop + T_Live**; logon-trigger only | interactive — T_Live, do not touch |

Result: **1 of 8 was interactive by accident; 7 genuinely require the interactive
session** (desktop-spawn, per-user DPAPI, or the `G:` mount). The IMAP half of task 5
uses a plaintext file credential (`.private/secrets/imap_info_quantmechanica.json`,
`sourcing_intake_sweep.py:99`) and would survive session 0, but its codex+agy analyst
half does not — so the task as a whole stays interactive.

---

## 3. Fixes applied

### Fix 1 — `QM_WorkItemLogPruner_Daily_0310`: Interactive → SYSTEM  (the one accident)

`prune_workitem_logs.py` only touches `D:\QM\reports` `*.log` files and the local
`farm_state.sqlite`; no terminal64, no DPAPI, no `G:`, no desktop. Moved to a
`ServiceAccount/SYSTEM` principal (runs in session 0 regardless of interactive session
state).

- Live change applied via `Set-ScheduledTask` (principal only; action/trigger/settings
  unchanged).
- **Verification (it actually runs):** operational events after the change —
  `110 → 325(transient, same second) → 200` (action launched, python.exe pid 5352)
  → `201/102` completed for `NT AUTHORITY\SYSTEM`; `LastTaskResult = 0x00000000`.
  Under the old Interactive principal it was stuck `110 → 325` with no `200`. The `325`
  is now instantaneous (queued→started same second) rather than terminal.
- **Source of truth:** `tools/strategy_farm/install_workitem_log_pruner_scheduled_task.ps1`
  (new; registers as SYSTEM, documents the dependency analysis and rollback).
- **Rollback:**
  `$p = New-ScheduledTaskPrincipal -UserId 'qm-admin' -LogonType Interactive -RunLevel Highest;`
  `Set-ScheduledTask -TaskName 'QM_WorkItemLogPruner_Daily_0310' -Principal $p`
  (baseline XML saved to scratchpad `task_rollback/`).

### Fix 2 — the self-heal path was silently broken by an output-parse bug

The factory's worker self-heal was already re-architected (ticket 7abd518a, 2026-07-26)
so the **SYSTEM** watchdog spawns workers into the interactive session via
`run_in_console_session.ps1` (WTSQueryUserToken + CreateProcessAsUser) instead of
delegating to the dead interactive `WorkerDedupe` task. `run_in_console_session.ps1`
selects Active-then-Disconnected, so it **works into the disconnected session 3** —
which is precisely why it heals while InteractiveToken scheduled tasks cannot.

But the heal still failed at the reporting/verification step:

- `run_in_console_session.ps1:158` always emits
  `LAUNCHED pid=<n> into console session <sid>`.
- `factory_watchdog.ps1:79` (and the identical helper in `tester_cache_purge.ps1:60`)
  matched `into (?:interactive )?session (\d+)` — which never accepts the word
  `console`.
- Consequence (evidence, `factory_watchdog.jsonl`, 2026-07-26 18:00 and 19:15): the
  launcher **succeeded** — `WAIT_EXIT pid=… code=0` with all nine worker PIDs spawned —
  yet the watchdog threw `"returned no session evidence"`, recorded **`heal_failed`**,
  and skipped its own post-spawn verification (workers_after / wrong-session check,
  `factory_watchdog.ps1:88-98`). The factory physically healed but reported failure and
  could never emit a clean `worker_dedupe_heal`.

Fix: broaden the label to any single word — `into (?:\w+ )?session (\d+)` — in both
consumers.

- `factory_watchdog.ps1` (heal-evidence regex, with comment).
- `tester_cache_purge.ps1` (identical worker-respawn helper, same bug).
- **Deterministic proof:** against the real captured line
  `LAUNCHED pid=9732 into console session 3 …`: old regex → **no match**; new regex →
  match, `captured_session=3`; new regex still matches legacy `interactive session`
  (sid 2) and bare `session` (sid 4).
- **Regression guard:** `tools/strategy_farm/tests/test_factory_watchdog_interactive_heal_static.py`
  extended to assert the launcher emits `console session` and that both consumers use
  the broadened pattern and not the interactive-pinned one. `2 passed`.
- **Rollback:** `git revert` of this commit (source-only change; no live task touched).

---

## 4. Self-heal path verified end-to-end (not asserted)

The heal chain has three links; each is shown, not assumed:

1. **Transport — SYSTEM → disconnected session 3 spawn.** Proven by the pre-existing
   `factory_watchdog.jsonl` records (2026-07-26 18:00, 19:15): the SYSTEM watchdog,
   via `run_in_console_session.ps1`, launched `start_terminal_workers --dedupe` into
   `console session 3` and returned `WAIT_EXIT … code=0` with nine terminal-worker PIDs.
2. **Parse — watchdog recognizes the transport's output.** Proven deterministically in
   §3 Fix 2 (old fails, new matches sid=3). With the fix, that same transport now
   records `worker_dedupe_heal` and runs the post-spawn verification instead of a false
   `heal_failed`.
3. **Healer is alive as SYSTEM (not queued).** Forced one watchdog cycle:
   principal `SYSTEM/ServiceAccount`; it wrote a fresh record (`13:50:22Z`,
   `action=realstall_guarded`, `workers=9/9`, `session_lost=false`) that fully evaluated
   9 workers + 8 active work-items and correctly **guarded** (took no destructive action
   because active multisymbol work with recent progress is present); `LastResult=0x0`.
   The healer runs to completion every cycle — unlike the queued interactive class.

A live worker-shortage was **not** manufactured: reducing worker count would interfere
with the eight in-flight backtests (T5 disabled, T9 reserved), which the constraints
forbid. Links 1+2+3 together establish the path: transport (real log) × parse fix
(deterministic) × healer alive (live run).

Task 6 (`WorkerDedupe`) is therefore **superseded** for self-heal: the watchdog no
longer delegates to it (`test_…:14` asserts the delegation is gone;
`factory_watchdog.ps1:1181-1189` uses the token launcher). The interactive task remains
only as a manual convenience and can be retired at OWNER discretion.

---

## 5. Tasks that genuinely require an interactive session — proposed delivery

These must **not** be left as silently-queued InteractiveToken tasks. Recommended,
in priority order; none applied here (each needs OWNER credential/authority or touches
T_Live / factory-restart, which is out of this task's remit).

1. **Systemic (recommended): a SYSTEM "interactive dispatcher".** One SYSTEM-principal
   timer that launches each genuinely-interactive job into the live session via
   `run_in_console_session.ps1` (the now parse-fixed, proven transport). Because it uses
   the real logged-on user token it gets the desktop, the `G:` mount, and the user
   DPAPI context — and it is immune to the disconnected-session queueing (Active-then-
   Disconnected selection). Covers tasks 2,3,4,5,6. Low-risk to extend since the
   transport is already in production for worker heal.
2. **`AgyGovernor` (task 2) — quick win, OWNER credential.** It needs only DPAPI +
   network (no desktop, no `G:`). `LogonType=Password` as qm-admin decrypts DPAPI and
   runs whether logged on or not:
   `schtasks /change /tn QM_StrategyFarm_AgyGovernor /ru qm-admin /rp <password>`.
   Requires OWNER to supply the password (stored by Task Scheduler in the credential
   vault, never the repo). S4U/SYSTEM will **not** work (no DPAPI key).
3. **`GeminiOrchestration` (task 4).** Password principal does **not** help — `G:`
   (Google Drive Desktop) mounts only in the interactive session. Either deliver via
   the §5.1 dispatcher, or repoint `run_agent_orchestration_task.py` off `G:\My Drive`
   onto the repo's `docs/ops` vault mirrors (then Password principal suffices for the
   agy DPAPI half).
4. **`Live_MT5_SessionSupervisor` / `T_Live_AtLogon` (tasks 7,8).** T_Live-critical;
   **not touched** per hard constraint. A SYSTEM counterpart already exists
   (`QM_LiveSupervisor_Watchdog_SYSTEM`, running, `0x41301`); confirm it fully covers
   live-terminal recovery, then these two can stay logon-triggered (they only fire at an
   actual interactive logon, so the queue-death does not affect their trigger model).

**Not recommended:** re-enabling `QM_TSCon_Console_OnDisconnect` to force the session
Active. It would revive all InteractiveToken tasks at once but it was deliberately
disabled as the RDP-disconnect fix and it manipulates the live T_Live session — OWNER
decision, and `tscon` is forbidden to me.

**Residual gap (documented, not fixed):** the watchdog's heaviest escalation
(full-reset / deferred-protection) still calls
`Start-ScheduledTask QM_StrategyFarm_FactoryON_AtLogon` (InteractiveToken) at
`factory_watchdog.ps1:1056,1160`; that escalation would queue while the session is
disconnected. The common worker-shortage heal (fixed above) does not depend on it, and
the realstall-guard suppresses full-reset while active work is progressing, so it is not
currently firing — but it should eventually route through the §5.1 dispatcher instead of
an InteractiveToken task. Changing the Factory_ON path is out of scope here (I may not
run Factory_ON).

---

## 6. Files changed / evidence

- `tools/strategy_farm/install_workitem_log_pruner_scheduled_task.ps1` (new; SYSTEM installer + rollback).
- `tools/strategy_farm/factory_watchdog.ps1` (heal-evidence regex broadened).
- `tools/strategy_farm/tester_cache_purge.ps1` (identical respawn-helper regex broadened).
- `tools/strategy_farm/tests/test_factory_watchdog_interactive_heal_static.py` (regression guard; `2 passed`).
- Live: `QM_WorkItemLogPruner_Daily_0310` principal Interactive→SYSTEM (verified rc=0).
- Rollback XML baselines for all 8 tasks: scratchpad `task_rollback/` (not committed — contain host SIDs).
