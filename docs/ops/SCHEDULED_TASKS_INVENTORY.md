# QuantMechanica — Scheduled-Task Inventory (canonical)

**Last consolidated:** 2026-06-01 (Claude, OWNER-directed)
**Single source of truth:** `tools/strategy_farm/qm_tasks.manifest.ps1`
**Drivers:** `tools/strategy_farm/Factory_ON.ps1` / `Factory_OFF.ps1` (desktop shortcuts
"QM Factory ON/OFF") dot-source the manifest.

This is the one canonical list of every `QM_*` Windows Scheduled Task on the VPS,
its category, and how the ON/OFF scripts treat it. The desktop ON/OFF shortcuts are
**not** a full job inventory — they manage only FACTORY + AI and *ensure* ALWAYS-ON;
this document is the complete picture.

## How the categories behave

| Category | Factory ON | Factory OFF |
|---|---|---|
| **FACTORY** (dispatch engine) | enable + start | stop + disable |
| **AI** (agent orchestration) | enable + start | stop + disable |
| **ALWAYS_ON** (dashboards/health/alarm/briefs/snapshot/housekeeping) | **ensure enabled** | **left running** |
| **ENFORCE_DISABLED** (session-0 respawn hazards) | force-disable if drifted | left disabled |
| **DECOMMISSIONED** (legacy/paused) | not touched | not touched |

Key point: with the factory **OFF you still get** the morning brief, dashboards,
health checks, the Gmail alarm, the public snapshot, and housekeeping — by design.
ON additionally re-enables any ALWAYS_ON task that drifted to Disabled (reboot / accident).

## FACTORY — dispatch engine

| Task | Schedule | Runs |
|---|---|---|
| `QM_StrategyFarm_Pump_5min` | 5 min | `run_pump_task.py` (dispatch MT5 + auto-spawn Codex + record builds) |
| `QM_StrategyFarm_Tick_5min` | 5 min | `farmctl.py tick` |

Plus (not tasks): the 10 `terminal_worker.py` daemons spawned **in the user session**
by Factory_ON (visible mode), and a one-shot `farmctl.py repair`.

## AI — agent orchestration

| Task | Schedule | Instances (`--max-sessions`) |
|---|---|---|
| `QM_StrategyFarm_AgentRouter_5min` | 5 min | n/a (router) |
| `QM_StrategyFarm_CodexOrchestration_15min` | 15 min | **5** |
| `QM_StrategyFarm_GeminiOrchestration_15min` | 15 min | 1 |
| `QM_StrategyFarm_ClaudeOrchestration_15min` | 15 min | **5** |
| `QM_StrategyFarm_QuotaReceiver` | continuous | n/a |

**Instance count lives in THREE places that must stay in sync** (OWNER 2026-06-01: Codex + Claude = 5):
1. `agent_router.py` `DEFAULT_AGENT_REGISTRY[*].max_parallel` — routing cap.
2. `install_agent_orchestration_scheduled_tasks.ps1` `MaxSessions` — task arg `--max-sessions`.
3. (Claude only) `D:\QM\strategy_farm\CLAUDE_BUDGET_POLICY.json` `max_sessions_per_run` — budget cap; effective = min(arg, cap). Default in `run_agent_orchestration_task.py` is also 5.

## ALWAYS_ON — support layer (left running by Factory OFF)

| Task | Schedule | Runs |
|---|---|---|
| `QM_StrategyFarm_Cockpit_2min` | 2 min | `render_cockpit.py` |
| `QM_StrategyFarm_Dashboard_Hourly` | hourly | `dashboards/render_dashboards.py` |
| `QM_StrategyFarm_Health_15min` | 15 min | `farmctl.py health` |
| `QM_StrategyFarm_GmailAlarm_Hourly` | hourly | `run_gmail_alarm_task.py` (sanctioned alarm + 06:05 digest) |
| `QM_StrategyFarm_MorningBrief_0700` | 07:00 | `morning_brief.py` (email) |
| `QM_MorningBriefing_Vault` | 06:00 | `morning_brief.py` (vault) |
| `QM_Public_Snapshot_Hourly` | hourly | `run_public_snapshot_task.ps1` (quantmechanica.com JSON) |
| `QM_StrategyFarm_InboxCleanup_Daily` | daily | `inbox_cleanup.py --days 7` |
| `QM_StrategyFarm_WorktreeClean_4h` | 4 h | `run_worktree_clean_task.py` |
| `QM_WorkItemLogPruner_Daily_0310` | 03:10 | `prune_workitem_logs.py` |

> Note: there are **two** morning-brief tasks — `QM_MorningBriefing_Vault` (06:00, vault
> write) and `QM_StrategyFarm_MorningBrief_0700` (07:00, email). Both invoke
> `morning_brief.py`. Kept both intentionally; if one is redundant, retire the 06:00 vault one.

## ENFORCE_DISABLED — must stay off (session-0 respawn hazards)

| Task | Why disabled |
|---|---|
| `QM_StrategyFarm_Repair_Hourly` | spawned SYSTEM/session-0 workers after a crash; repair now runs ONCE inline in Factory_ON. **Was found drifted to Enabled on 2026-06-01 and re-disabled.** |
| `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` | spawned daemons as SYSTEM/session-0 (headless); workers now spawn in the user session via Factory_ON. |

## DECOMMISSIONED — legacy / paused (NOT toggled by ON/OFF)

Left disabled; revive by hand only with OWNER intent. Three groups (full list in the manifest):

- **Paperclip-era relics** (paths under `C:\QM\paperclip\...\<GUID>\`): backup, sentinels,
  daily status mail, old dashboard render, drive-git-exclusion, WS30 gate, infra health,
  kanban archive, stale-lock watchdog, old public-snapshot export/health, all `QUA*`
  ops-cycle/heartbeat/blocker tasks, recovery-orphans cleanup, runtime-health scan,
  subscription guardian.
- **Superseded V5 pre-strategy-farm**: `AggregatorState_1min`, `DWX_HourlyCheck`,
  `GateEvaluator_5min`, `MT5_Worker_T1..T5` (old session-0 workers), `Phase_Orchestrator`,
  `PipelineHealth_Watchdog`, `PipelineState_Build_Hourly`, `PythonRuntimeHealth_10min`,
  `Research_Wake_Check`, `TokenCostBudget*`.
- **Intentionally-paused strategy-farm tasks**: `AutonomousWake_Hourly`,
  `BoardAdvisor_Hourly`, `ClaudeVerify_4h`, `Q08Regen_Resume`.

> Optional follow-up: these legacy tasks are harmless while disabled but clutter Task
> Scheduler. They can be bulk-`Unregister-ScheduledTask`'d once OWNER confirms none will
> be revived. Not done automatically (deletion is irreversible).

## Non-QM tasks (not ours)

`SpaceAgentTask`, `Sqm-Tasks`, `SyspartRepair` — OS/OEM tasks, outside QM scope.
