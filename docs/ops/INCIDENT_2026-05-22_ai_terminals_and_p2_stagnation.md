# Incident Note: "AI terminals closed" report + P2 promotion stagnation

Date: 2026-05-22
Status: RESOLVED — no outage found; one upstream throughput issue routed to Codex
Raised by: OWNER (morning report)
Investigated by: Claude

## Summary

OWNER reported that "all terminal windows were closed this morning" and then
clarified the concern was the **AI agent terminals**, not the MT5 backtest
windows. Investigation found **no AI orchestration outage**. The scheduled-task
agent system was healthy and self-healing throughout. One genuine, unrelated
issue was confirmed — the pipeline has promoted nothing past P2 in 12h — and was
routed to Codex.

## Timeline / report

- OWNER observed AI/terminal windows absent this morning and asked for the cause.
- First reading assumed the MT5 `terminal64.exe` windows; OWNER corrected: the
  concern is the **AI agent terminals**.
- Full sweep of scheduled tasks, processes, logs, and router state followed.

## Investigation findings (06:30–06:45 local, 2026-05-22)

| Component | State | Evidence |
|---|---|---|
| VPS uptime | 2d 13h, no reboot | last boot 2026-05-19 17:14; no shutdown events 24h |
| `QM_StrategyFarm_Pump_5min` | Ready, ran 06:40, exit `0x0` | `pump_task_20260522T044001Z.log` clean |
| `QM_StrategyFarm_AgentRouter_5min` | Ready, ran 06:40, exit `0x0` | task scheduler |
| `QM_StrategyFarm_QuotaReceiver` | Running | `quota_receiver.py` pid 2536, up since 05-19 |
| `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` | Ready, 5-min repeat | LastRun 06:40 exit 0 |
| Codex agents | actively working | live logs `codex_research_*.log` (06:42:54) + `codex_g0_*.log` (06:42:22); 3 codex processes |
| Gemini | idle, 0 processes | **normal** — 0 `IN_PROGRESS` tasks (4 tasks in `REVIEW`) |
| MT5 factory | 10/10 terminals running Q02 | `farmctl mt5-slots` |
| Task Scheduler errors (6h) | none | no 103/203/331 events for any farm task |
| Orphaned / stuck `agent_tasks` | none | router `running: 0`, no `IN_PROGRESS` rows pre-incident |

## Root cause — "AI terminals closed"

There is **no persistent "AI terminal"** in this architecture. The AI agents are
scheduled-task driven:

- The **Pump** (`run_pump_task.py`, every 5 min) spawns Codex agent runs. Codex is
  launched **headless** — `farmctl.py` uses `subprocess.CREATE_NO_WINDOW`, so there
  is deliberately no visible window.
- Scheduled tasks run in **session 0** and survive RDP disconnect/logoff.
- Anything launched **interactively** inside an RDP session (a hand-started
  `codex` / `gemini` / `claude` console) terminates when that session ends.

The most consistent explanation: an interactive RDP session was logged off
(not merely disconnected), closing interactively-launched AI console windows.
The session-0 scheduled-task orchestration was unaffected and continued —
Codex completed G0 reviews and research after the reported time. **No restart
or recovery action was required and none was taken.**

## Confirmed real issue — P2 promotion stagnation

Health check `p_pass_stagnation` = **FAIL**: 0 P3+ PASS verdicts in the last 12h.

This is upstream and unrelated to the terminal report. The P2/Q02 backtests for
`QM5_10075`, `QM5_10076`, `QM5_10079` run past the **30-min phase timeout**
(health `active_row_age` WARN observed a worst case of 34.8m; multiple terminals
were on `run_02` retry configs). A timed-out run never records a P2 PASS, so
nothing is promoted to P3+. Likely cause: slow per-tick EA logic — see the
`QM5_1044` per-tick full-EMA recompute precedent.

## Resolution / actions

1. No AI orchestration restart performed — the system was healthy; a restart
   would have interrupted live Codex work and orphaned tasks.
2. Deliberately-disabled tasks (`QM_StrategyFarm_AutonomousWake_Hourly`,
   `QM_StrategyFarm_BoardAdvisor_Hourly`) were left disabled — they were retired
   when the operation moved to the Friday worker-prompt model.
3. P2-timeout investigation routed to Codex: `agent_tasks` ops_issue
   **`854899ee-9beb-4e8a-9f3d-70cb0603f74e`** (priority 7, `IN_PROGRESS`).
   Acceptance: P2 backtests for the named EAs complete inside the 30-min cap and
   record real verdicts; fix EA performance rather than raising the timeout.

## Operating guidance

- The AI agents do not need open terminal windows. Rely on the scheduled tasks
  (`Pump`, `AgentRouter`) — they run in session 0 and survive logoff.
- To check AI health without windows: `agent_router.py status`,
  `farmctl.py health`, and the live logs under `D:/QM/strategy_farm/logs/`.
- Earlier-self-resolved health checks this session: `quota_snapshot_fresh`
  (Claude snapshot refreshed) and `active_row_age` WARN (cleared by the 06:40
  pump). Only `p_pass_stagnation` remained, now owned by task `854899ee`.
