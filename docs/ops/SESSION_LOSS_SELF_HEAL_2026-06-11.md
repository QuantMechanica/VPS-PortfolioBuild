# Interactive-Session Loss → Factory Down: Forensics + Self-Heal (2026-06-11)

## Symptom (OWNER, recurring)

Reconnecting RDP (phone) lands in a **new** session; FactoryON_AtLogon then starts the
factory — but before that the factory had been standing for hours, silently.

## Forensic timeline (event-log evidence)

Sessions died three times in ~24h while parked on the physical console
(tscon keepalive), each time **instantly destroyed without a logoff**:

| Session | Death (local) | Evidence |
|---|---|---|
| 1 | 2026-06-10 11:03:03 | LSM event 40 reason 23; per-session user services 7031; no Winlogon 7002 |
| 3 | 2026-06-11 05:08:11 | same — preceded 05:08:03-10 by a burst of process-start failures **0xc0000142** (DLL_INIT_FAILED = desktop-heap/resource exhaustion) on git.exe/node.exe/powershell.exe; GoogleDriveFS G: unmount at death |
| 4 | 2026-06-11 09:45:47 | same signature, no 0xc0000142 burst |

- `tscon_keepalive.jsonl` fired 1-2s after each death and found **no session at all**
  (`sid:"", state:""`) — teardown was immediate, not a timeout.
- No session-limit policies set (MaxDisconnectionTime=0, MaxIdleTime=0, fResetBroken=0).
- Two `LiveKernelEvent 193` (dxgkrnl) dumps + one explorer.exe crash (twinui.pcshell.dll)
  in the same period → RDP **WDDM display driver** instability is a likely co-trigger
  (known Server 2019/2022 issue).
- SharedSection already raised: `1024,32768,4096`.
- Factory downtime per death = until OWNER's next manual login (up to hours):
  with no qm-admin session, `WTSQueryUserToken`/`CreateProcessAsUser` has no token,
  so the existing watchdog respawn could not heal.

## Root-cause summary

Triggers vary (desktop-heap/resource exhaustion confirmed once; dxgkrnl/WDDM suspected
twice) — but the **systemic gap** was singular: nothing detected "interactive session
gone" and nothing could restore one without OWNER.

## Fix (deployed 2026-06-11)

1. **Watchdog session-loss reboot-heal** (`tools/strategy_farm/factory_watchdog.ps1`,
   runs as SYSTEM every 15 min):
   - New detection: factory ON + **no qm-admin session** in qwinsta.
   - Heal: controlled `shutdown /r /t 60` → autologon recreates the console session →
     `FactoryON_AtLogon` restores the factory. Max gap ≈ 30-45 min, hands-free.
   - Guards: confirm on 2 consecutive runs; 6h cooldown
     (`D:\QM\reports\state\watchdog_session_heal.json`); requires AutoAdminLogon=1 +
     LSA `DefaultPassword` secret (verified present 2026-06-11 via SYSTEM check —
     the registry value is empty because Sysinternals Autologon stores it as LSA
     secret; boot 2026-06-10 10:11 logged on 46s after start = autologon works);
     hard-refuses while any T_Live terminal runs (Hard Rule).
   - New JSONL field `session_lost`; actions: `session_lost_pending_confirm`,
     `healed_session_reboot`, `session_lost_cooldown`, `session_lost_no_autologon`,
     `session_lost_tlive_guard`.
2. **WDDM mitigation**: `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal
   Services\fEnableWddmDriver = 0` (RDP falls back to XDDM; effective next reboot) —
   standard mitigation for dxgkrnl-driven session drops on Server 2022.
3. **Cockpit watchdog pulse**: cockpit.html now shows the last watchdog action,
   worker count, session state and age (`WATCHDOG noop_healthy // 10/10 workers //
   session ok // 3m ago`) so a stand-still is visible at a glance.

## Verification

- Watchdog parse-checked + live run: `noop_healthy`, `session_lost:false`.
- LSA secret check (SYSTEM one-shot task): `SECRET_EXISTS`.
- Cockpit re-rendered with pulse row.

## Residual risks

- If autologon breaks again (password change without re-running Sysinternals
  Autologon), the watchdog logs `session_lost_no_autologon` and does NOT reboot —
  OWNER must log in once and re-set autologon.
- Reboot-heal interrupts any in-flight backtests (workers re-claim after restart —
  same behavior as the verified reboot chain).
- Desktop-heap exhaustion root cause (what leaked on 06-11 05:08) is not yet
  isolated; if heals recur, trend the watchdog JSONL + 0xc0000142 events.
