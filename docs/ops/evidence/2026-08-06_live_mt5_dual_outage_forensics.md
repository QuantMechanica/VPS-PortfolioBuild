# Live MT5 Dual Outage 2026-08-06 — Phase-A Forensics (Claude)

**Status:** Terminals recovered manually by OWNER 06:25 local; automation failed for
2h33m. Root-cause chain established from append-only evidence; recovery-chain fix
identified but NOT yet applied (permission gate). Codex SOL-MAX independent
forensics to follow per the standing dual-forensics protocol (2026-08-05).

All timestamps **local (W. Europe Standard Time, UTC+2)** unless suffixed Z.

## 1. Incident timeline (evidence-anchored)

| Time | Event | Evidence |
|---|---|---|
| 02:35:32 | T_Live still trading (deal #150785634 buy 0.01 XAUUSD @4290.76, SL present) | `C:\QM\mt5\T_Live\MT5_Base\Logs\20260806.log` |
| 03:52:37 | **VPS host crash** — unexpected shutdown, no clean stop | System Event Log Id 6008; Id 41 (Kernel-Power) 03:53:09 |
| 03:53:26~ | Reboot + qm-admin autologon; session 1 Active | qwinsta via watchdog jsonl 01:53:47Z |
| 03:53:41–44 | `QM_T_Live_AtLogon` ran → **T_Live_ON.ps1 exit 2 after 3 s** (early guard; script writes no log — exact path unproven; prime suspect: fail-closed CIM process-inventory probe ~52 s after boot) | TaskScheduler Operational 100/201; task LastTaskResult=2 |
| 03:53:56 | `QM_FTMO_AtLogon` ran → exit 0 **without launching** (by design: baked `PARKED` contract in FTMO_ON.ps1, OWNER 2026-07-26) | FTMO_ON.ps1:13-15,43; task result 0 |
| 03:54:10–22 | Resident `QM_Live_MT5_SessionSupervisor` started, **died after ~12 s** (should loop forever at 10 s interval). Restarted every 10–15 min all night (15-min time trigger + supervisor-watchdog kicks) — died every time. Root cause open → Codex forensics. | TaskScheduler events; `live_supervisor_watchdog.log` kicks 02:10Z…04:25Z; heartbeat stale (age≈600) between kicks |
| 03:53→06:25 | **SYSTEM minute-watchdog saw the outage correctly every minute** (`dxz=False`, status critical) but refused its RunEx restore path: `session_supervisor_start_blocked_task_contract:` `QM_T_Live_AtLogon:allow_demand_start` &#124; `QM_FTMO_AtLogon:allow_demand_start` &#124; `QM_Live_MT5_SessionSupervisor:trigger_count=2` → fail-closed, no recovery. Reboot path irrelevant (session existed) and disabled anyway (`-NoReboot` in task action). | `D:\QM\reports\state\live_uptime_watchdog.jsonl` 01:53Z–04:2xZ, ~150 consecutive entries |
| 06:25:14/16 | **OWNER manually started both terminals** (parent process = explorer.exe, session 1) | Win32_Process ParentProcessId → explorer.exe |
| 06:25:19 | T_Live authorized (acct 4000090541), 24 EAs loaded, "trading has been enabled — hedging mode", 2 positions + 2 orders synchronized | T_Live journal 20260806.log |
| 06:29:18/56 | Live trading resumed provably: EURUSD sell-stop cancel/replace, XAUUSD market buy 0.02 executed | T_Live journal |

Downtime: **03:52:37 → 06:25:15 = 2 h 32 m 38 s.** Open positions remained
broker-side SL-protected throughout (all open tickets carried server-side SL).
The damage is missed entries, not unprotected risk.

## 2. Root causes (three independent layers)

1. **Trigger:** VPS host freeze/crash class (known: `project_qm_vps_host_freeze_class_2026-07-08`) — third-party/host level, not preventable on our side.
2. **Recovery chain dead — primary cause of the 2.5 h:** task-definition drift vs. the baked recovery-task contract in `T_Live_Watchdog.ps1` (`Get-RecoveryTaskContractState`):
   - `QM_T_Live_AtLogon`, `QM_FTMO_AtLogon`: `AllowDemandStart=True` (contract: **False** — "logon-only; demand starts queue in disconnected RDP sessions", install_live_uptime_tasks.ps1:212-216)
   - `QM_Live_MT5_SessionSupervisor`: **2 triggers** (logon + 15-min time trigger, StartBoundary 2026-07-25) (contract: exactly 1 logon trigger)
   - The fail-closed contract check then blocked the *only* working restore path (RunEx start of the resident supervisor) every minute for 2.5 h. Fail-closed turned a cosmetic drift into a hard outage.
   - Drift origin hypothesis: the 15-min trigger + demand-start flags were added ~07-25 as a redundancy layer without updating the baked contract (or vice versa). To be pinned by Codex (task XML mod dates, repo history of installer).
3. **Secondary defects exposed:**
   - `T_Live_ON.ps1` exit 2 at 03:53:41 — script has **no log file**; failure path unreconstructable. Observability defect.
   - Resident supervisor dies ~12 s after every start during 03:54–06:24 but runs stably since 06:25 (current PID 11280, heartbeat healthy). Unexplained → Codex.
   - `-NoReboot` on the watchdog task: the last-resort reboot heal is permanently off (consistent with OWNER "KEIN Reboot-Test" doctrine, but should be a conscious OWNER decision, documented).
   - **No immediate alarm channel:** watchdog wrote `critical` every minute for 2.5 h; mail governance (06:00 HTML + FAIL-digest only) never paged OWNER. OWNER found the outage himself.

## 3. FTMO terminal — contract vs. reality

`FTMO_ON.ps1` and both watchdog layers bake `expectedFtmoState='PARKED'`
(OWNER 2026-07-26, review expiry 2026-08-25): never relaunch, alarm if running.
Reality: OWNER runs the FTMO terminal (watchdog has alarmed
`expected_parked_but_running:FTMO` continuously, incl. before the crash;
FTMO-M1 campaign Sat 08-08 planned). Under the current contract FTMO will
**never** be auto-recovered. Needs OWNER word: flip baked contract to RUNNING
(3 files: FTMO_ON.ps1, Live_MT5_SessionSupervisor.ps1, T_Live_Watchdog.ps1)
or re-park the terminal.

## 4. Trading impact — QM5_13213 USDJPY confirmed miss

`QM5_13213_balke-gmt3-range-breakout` (USDJPY H1, magic 132130000) places its
daily bracket (BUY_STOP + SELL_STOP) at **exactly 06:00:00 broker time**
(= 05:00 local, inside the outage window):

- 08-04 06:00:00 broker: ENTRY_ACCEPTED buy stop 157.742 / sell stop 157.221
- 08-05 06:00:00 broker: ENTRY_ACCEPTED buy stop 157.750 / sell stop 157.302
- **08-06: terminal dark at 06:00 broker; EA re-init 07:29:58 broker; zero ENTRY events today** → the day's range-breakout bracket was never placed.

Evidence: `C:\QM\mt5\T_Live\MQL5\Files\QM\QM5_13213_ea-13213.log` (path base
`C:\QM\mt5\T_Live\MT5_Base\`). Quantifying the foregone PnL requires replaying
today's 06:00-broker range against realized USDJPY path — optional follow-up;
the structural miss itself is proven. Other sleeves are stateless intraday/daily
logics that resumed normally (proof: trades at 06:29).

## 5. Fix plan

1. **Immediate (blocked by session permission gate, needs OWNER run/consent):**
   reconcile the three drifted task definitions to the contract —
   `AllowDemandStart=False` on `QM_T_Live_AtLogon` + `QM_FTMO_AtLogon`; remove
   the 15-min time trigger from `QM_Live_MT5_SessionSupervisor` (keep logon
   trigger PT45S; running instance untouched). Then force one
   `QM_T_Live_Watchdog` run and verify `recovery_task_contract_ready:true` in
   `live_uptime_watchdog.json`.
2. **Codex SOL-MAX independent forensics + durable fix** (dual-forensics
   protocol; independence seal — no reading of this doc before its Phase A is
   committed): supervisor 12-s death loop, T_Live_ON exit-2 path, drift origin,
   add file logging to both launchers, safe end-to-end test design (test kills
   supervisor process only, never terminals).
3. **OWNER decisions:** FTMO RUNNING vs PARKED (§3); immediate-alarm channel for
   live-terminal-down (governance change to mail rules); `-NoReboot` stance.

## 6. Verification state at close of Phase A

- T_Live: RUNNING, healthy, trading (journal evidence §1).
- FTMO: RUNNING against baked PARKED contract (standing alarm, no auto-recovery).
- Supervisor: RUNNING PID 11280, heartbeat fresh, scheduler-owned.
- Watchdog: still reporting `recovery_task_contract_ready:false` → **the live
  book currently has NO working automatic recovery for the next crash.** This is
  the urgent open risk until §5.1 lands.

## 7. Cross-review addendum (after Codex Q-A seal, 2026-08-06 ~10:20)

Codex's independent forensics (`2026-08-06_live_mt5_dual_outage_codex_forensics.md`,
sealed at commit `cc6965ac6` before reading this document) agrees on every host
fact. I accept two corrections to this report:

1. **Supervisor loop reframed.** §2 of this report called it a "12-s death
   loop". Codex quantified all 20 completed supervisor actions: every one
   returned result 0 with durations 11.3–42.1 s — one-cycle-equivalent
   behavior, not a crash signature. The precise normal-exit path is
   NOT ESTABLISHED and is now unattributable, because my own 07:03 task
   reconcile overwrote the historical task XML (TaskScheduler Event 140).
2. **Drift dating.** The three-blocker contract drift is proven present by
   2026-07-26T16:02:48Z — ten days before the crash. My "July redundancy
   layer" origin hypothesis remains a hypothesis; the audit window that could
   identify the actor has rolled off.

Joint verdict: three independent recovery failures coincided (unlogged
launcher exit-2 — boot-window CIM uncertainty is the leading but unproven
branch; FTMO PARKED contract behaving exactly as then designed; task-contract
drift fail-closing the RunEx path). Hardening is implemented and verified
(`cd689aae9`): centralized reasoned exits + append-only launcher journal
(`live_launcher_events.jsonl`, guarded best-effort writes) + bounded
boot-window CIM retry (3 probes / ≤15 s / uptime ≤10 min, PS 5.1-safe).
Remaining: the supervisor-kill end-to-end recovery test (design §"Safe
end-to-end" in the Codex doc) awaits an OWNER-approved window.

## 8. End-to-end recovery test — EXECUTED AND PASSED (2026-08-06 ~15:24)

OWNER approved ("Go") and personally executed the single destructive step
(`taskkill /F /PID 11280` at ~15:21 local, via session prompt). Verification
per the Codex §Safe-E2E design:

| Criterion | Result |
|---|---|
| New supervisor appears | ✅ PID 3940, session 1, heartbeat 13:24:34Z (≈2 watchdog cycles after kill) |
| Scheduler-owned + ready | ✅ `scheduler_owned=true`, `reason=ready` |
| Restore path | ✅ `last_action=session_supervisor_started_or_verified_via_runex` — the exact RunEx path that was contract-blocked for 2.5 h during the night outage |
| Terminal integrity | ✅ DXZ PID 9872 created 06:25:14.288640, FTMO PID 10400 created 06:25:16.310761 — byte-identical, untouched |
| No reboot request | ✅ `consecutive_both_down=0`, no reboot action, errors empty |
| No launcher terminal-launch record | ✅ journal tail unchanged (last entries = 07:11 force_unsupported test records) |
| Watchdog end state | ✅ `healthy` |

**The incident circle is closed:** 03:52 host crash → dual forensics → task-
contract reconcile → FTMO RUNNING flip with reality-pinned profile → armed
reboot heal → launcher journaling + boot-window retry → alarm mailer +
04:45 safety sweep installed → **live-proven self-heal through the previously
dead RunEx path.** The recovery stack is now hardened AND demonstrated.
