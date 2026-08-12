# 2026-07-21 — RDP session-teardown fix + DXZ dashboard / dark-theme reversal

Two persistent-state changes from the 2026-07-21 session, recorded here because they change system
config and reverse a prior documented decision.

## A. RDP disconnect → factory-session teardown — root cause + fix

### Symptom (recurring)
OWNER repeatedly "thrown out" of RDP; on reconnect the interactive session and everything in it
(factory workers, T_Live, headless agents, Claude Code) was gone ("alles weg"). Watchdog then
issued `QM factory_watchdog` reboots (Event 1074) on genuine session loss — not a misfire.

### Diagnosis (evidence)
- The factory runs **visible in the autologon interactive session** (`Factory_ON.ps1` design).
- RDP disconnect policy is already correct: `MaxDisconnectionTime=0`, `fResetBroken=0`,
  `fInheritReconnectSame=1` — a plain disconnect should keep the session alive.
- Root cause: the **`QM_TSCon_Console_OnDisconnect` task** (`tscon_console_keepalive.ps1`) fires on
  every RDP disconnect (Event 24) and `tscon <sid> /dest:console`. Combined with the autologon
  console session + `fSingleSessionPerUser=1` + `FactoryON_AtLogon` respawn, the tscon-to-console
  and RDP reconnect race → the session is torn down (new session id on reconnect: 1→3), workers→0.
  The task ran at 20:24:24 exactly when the session died; `factory_watchdog.jsonl` shows
  `workers:0, session_lost:true` right after.

### Fix (minimal, reversible, zero lockout risk)
`Disable-ScheduledTask -TaskName 'QM_TSCon_Console_OnDisconnect'`. No RDP login setting touched
(`fDenyTSConnections=0` unchanged) — a disconnected session now simply persists via
`MaxDisconnectionTime=0`, and reconnect returns to the same live session. Worst case if MT5 needs an
active desktop: the factory wedges briefly (recoverable by the watchdog / on reconnect) instead of
dying — a softer failure than the current teardown.

**Rollback:** `Enable-ScheduledTask -TaskName 'QM_TSCon_Console_OnDisconnect'`.
**Status:** applied 2026-07-21 ~20:42 UTC; monitoring the next disconnect. Factory auto-recovers via
`FactoryON_AtLogon` regardless (proven: 9/9 workers + T_Live back within ~1 min of relogin).

## B. DXZ dashboard — investor-grade marketing view + dark-theme reversal

### Marketing view (OWNER: the dashboard is public advertising for the DXZ fund)
`render_dxz_journal.py` gained: a cumulative realized-P&L **growth curve** (deal-history, real close
dates), a monthly **P&L calendar** (each day green/red by realized net, weekly totals), and fund
**KPIs** (Realized P&L, Win Rate, **Profit Factor**, **Max Drawdown**, Best/Worst Day) alongside
Equity / Total Return / Risk, plus a data-freshness header. The redundant "Win/Loss by day" bar
chart was removed (the calendar covers it). All figures remain read-only from T_Live logs + the
AccountMonitor deal export — **no invented numbers** (Hard Rule preserved even in a marketing context;
e.g. win-rate 38.9% is shown honestly, carried by PF 2.06).

### Dark-theme reversal — reverses the 2026-07-20 light DL
`style.css` was flipped from the **Paper/Ink light theme (Design-System v2, OWNER-DL 2026-07-20)**
back to **dark** at OWNER request 2026-07-21: "Dark-Mode of v2" — keep v2's structure, typography and
steel-blue accent (`--signal #2954d4` → brightened for dark), only invert the palette to slate
(`--bg #0c0f16`, light text). The whole dashboard suite (Cockpit, Strategy Archive, DXZ Journal)
darkens via the shared `style.css` (100% var()-based → a `:root` flip suffices).

**Clarification (important):** "scheme colour on white" applies **only to an actual MT5 price chart**,
NOT the dashboard's own data-viz — calendar, equity curve and any graphs are **dark**. (`--chart-*`
tokens + a `.chart-white` utility exist in `style.css` for a future embedded MT5 chart, unused by the
dashboard.)

**Doc-status note:** `docs/ops/DESIGN_SYSTEM_V2_2026-07-20.md` (light/Paper-Ink) is now **superseded
on the light/dark axis** by this OWNER decision — v2's structure/typography/accent stand, the palette
is dark. Formalise as a dated DL if desired.

Commits: dashboard marketing view `7f40838fa`; dark-mode+charts-on-white `9614e0911`; charts-back-to-
dark `7240fa41c`; Win/Loss-drop `93a2bc246`.
