# QuantMechanica — Scheduled-Task Inventory (canonical)

**Last consolidated:** 2026-07-23 (weekly source-access backlog mail)
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
| **ALWAYS_ON** (dashboards/health/briefs/reboot diagnostics/snapshot/housekeeping) | **ensure enabled** | **left running** |
| **ENFORCE_DISABLED** (unsafe paths and OWNER opt-outs) | force-disable if drifted | left disabled |
| **DECOMMISSIONED** (legacy/paused) | not touched | not touched |

Key point: with the factory **OFF you still get** the morning brief, Friday
source-access report, dashboards, health checks, reboot diagnostics, the public
snapshot, and housekeeping — by design.
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
| `QM_StrategyFarm_CodexOrchestration_15min` | 15 min | **1** (see warning) |
| `QM_StrategyFarm_GeminiOrchestration_15min` | 15 min | 1 |
| `QM_StrategyFarm_ClaudeOrchestration_15min` | 15 min | **5** |

> `QM_StrategyFarm_QuotaReceiver` (Tampermonkey receiver) was **removed
> 2026-06-07** — never actually registered, browser-dependent, broke on every
> reboot. Superseded by `QM_StrategyFarm_QuotaPull` (ALWAYS_ON, headless API
> pull). See that section.

**Instance count lives in THREE places that must stay in sync** (OWNER 2026-06-01):
1. `agent_router.py` `DEFAULT_AGENT_REGISTRY[*].max_parallel` — routing cap.
2. `install_agent_orchestration_scheduled_tasks.ps1` `MaxSessions` — task arg `--max-sessions`.
3. (Claude only) `D:\QM\strategy_farm\CLAUDE_BUDGET_POLICY.json` `max_sessions_per_run` — budget cap; effective = min(arg, cap). Default in `run_agent_orchestration_task.py` is also 5.

> ⚠️ **Codex max-sessions MUST stay 1.** The codex CLI shares one
> `~/.codex/auth.json` OAuth token across all processes; concurrent sessions race
> on token refresh (`refresh_token_reused` 401) and **invalidate the whole login**.
> Setting codex=5 on 2026-06-01 re-broke auth ~54 min after re-login. 5 concurrent
> codex would need 5 separate Codex OAuth logins (not available). Codex throughput
> comes from the pump's build dispatch, not parallel orchestration sessions.
> Claude=5 is retained but **unverified for the same class of race** — monitor.

## ALWAYS_ON — support layer (left running by Factory OFF)

| Task | Schedule | Runs |
|---|---|---|
| `QM_StrategyFarm_Cockpit_2min` | 2 min | `render_cockpit.py` |
| `QM_StrategyFarm_Dashboard_Hourly` | hourly | `dashboards/render_dashboards.py` |
| `QM_StrategyFarm_Health_15min` | 15 min | `farmctl.py health` |
| `QM_MorningBriefing_Vault` | 06:00 | `morning_brief.py` — the one daily MorningBriefing mail plus Drive-vault archive |
| `QM_StrategyFarm_UnreadableLinks_Friday` | Friday 06:30 | `run_weekly_unreadable_links_task.py` — sends one deduplicated OWNER mail per ISO week containing unchecked links from the marked Priority-A block in `Strategie Links.md` plus access-related `DEFERRED` mailbox-intake rows. Discovery-only and EA-fidelity links are excluded. An atomic pre-SMTP week claim prevents duplicate delivery after a crash/state-write failure; only proven pre-send failures are retried. Runs as interactive `qm-admin` because the G: Vault mount is user-bound; 4 scheduler retries at 15-minute intervals cover a delayed Drive mount or proven pre-send failure. Explicit OWNER authorization: 2026-07-23. |
| `QM_StrategyFarm_MailboxSourceIntake_Daily` | 06:07 daily | `mailbox_source_intake.py` — read-only IMAP extraction plus policy-aware source triage. Runs fail-closed as interactive `qm-admin` because Codex/agy credentials are user-bound; `CODEX_HOME` is explicit. Success requires a verified terminal CSV status for every lead; `QUALIFIED` additionally requires both the matching factory-source row and a source-linked G0 card. The Codex return code remains diagnostic evidence. Failed, partial, transient-fetch, or capacity-delayed runs remain retryable. Each Codex attempt is capped at 30 minutes; a nonzero task gets 4 scheduler restarts at 15-minute intervals. |
| `QM_StrategyFarm_RebootDiagnostic_AtStartup` | startup +5 min | `run_reboot_diagnostic_mail_task.py` — sends one deduplicated German cause/recovery mail for each new Windows boot and retries failed delivery up to six times at five-minute intervals. A verified factory-watchdog marker adds the detailed session-loss analysis; otherwise Windows 1074/BugCheck/Kernel-Power evidence is classified conservatively. |
| `QM_Public_Snapshot_Hourly` | hourly | `run_public_snapshot_task.ps1` (quantmechanica.com JSON) |
| `QM_StrategyFarm_InboxCleanup_Daily` | daily | `inbox_cleanup.py --days 7` |
| `QM_StrategyFarm_WorktreeClean_4h` | 4 h | `run_worktree_clean_task.py` |
| `QM_WorkItemLogPruner_Daily_0310` | 03:10 | `prune_workitem_logs.py` |
| `QM_StrategyFarm_HourlyMonitor_60min` | 60 min | `hourly_monitor.ps1` — health triage: auto-fix reversible task-state drift, escalate auth/factory/T_Live to `D:\QM\reports\state\hourly_monitor.jsonl`. Install: `install_hourly_monitor_scheduled_task.ps1`. Fail-safe (DL-065). |
| `QM_StrategyFarm_TesterCachePurge` | 20 min | `tester_cache_purge.ps1` — if D: free <150GB: preserve protected active slots and captured Factory ON/OFF state, purge only idle regenerable `T*\Tester\bases`+`Agent-*` caches, then request only missing workers through `QM_StrategyFarm_WorkerDedupe`. Controller runs as SYSTEM; worker launch remains INTERACTIVE qm-admin. Never touches T_Live/FTMO/source ticks/reports. |
| `QM_StrategyFarm_QuotaPull` | 5 min | `quota_pull.py` — headless Codex+Claude limit pull. Hits the authenticated usage JSON endpoints (`chatgpt.com/backend-api/codex/usage`, `api.anthropic.com/api/oauth/usage`) with the OAuth tokens the CLIs already store, writes `quota_snapshot.json` (USED % per 5h/weekly window). **Replaces the Tampermonkey browser-scraper** (2026-06-07) — no browser, survives reboot. Runs as **SYSTEM** (reads world-readable token files). Read-only on tokens; never refreshes/writes them, so it cannot trigger the codex `refresh_token_reused` race. On 401/403 keeps last-good (health goes stale only if pulls persistently fail). |
| `QM_T_Live_AtLogon` / `QM_FTMO_AtLogon` | qm-admin logon +15s/+30s | Logon-only, idempotent exact-path cold start for DXZ and FTMO; demand start disabled because it queues while RDP is disconnected. |
| `QM_Live_MT5_SessionSupervisor` | qm-admin logon +45s, resident | Interactive `qm-admin`, `PT0S`, every 10s. Recovers an individually missing DXZ/FTMO inside the existing desktop session, including while RDP is disconnected. Explicit demand start is allowed only for the contract-checked `RunEx` helper, which pins the task to that session and verifies Scheduler PID = heartbeat PID. |
| `QM_T_Live_Watchdog` | 1 min | SYSTEM dual-live/session/profile/supervisor watchdog; controlled reboot only after confirmed total loss, with fail-closed process probes, non-empty SYSTEM-only Autologon secret, and exact principal/action/trigger/settings contracts for all three interactive recovery tasks. The maintenance flag is re-read immediately before `shutdown.exe` and during every countdown second. |

> Note: the duplicate **07:00 email** task (`QM_StrategyFarm_MorningBrief_0700`)
> was deleted 2026-06-01. The retained `QM_MorningBriefing_Vault` task is the
> single 06:00 MorningBriefing mail and also writes the Drive-vault archive.

## ENFORCE_DISABLED — unsafe paths and OWNER opt-outs that must stay off

| Task | Why disabled |
|---|---|
| `QM_StrategyFarm_Repair_Hourly` | spawned SYSTEM/session-0 workers after a crash; repair now runs ONCE inline in Factory_ON. **Was found drifted to Enabled on 2026-06-01 and re-disabled.** |
| `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` | spawned daemons as SYSTEM/session-0 (headless); workers now spawn in the user session via Factory_ON. |
| `QM_TSCon_Console_OnDisconnect` | caused a proven session-arbitration/desktop teardown race; must remain disabled. |
| `QM_StrategyFarm_HygieneReboot` | legacy forced-reboot path does not yet implement the live watchdog's exact recovery contracts and cancellable maintenance/process edge; keep disabled until separately hardened. |
| `QM_StrategyFarm_GmailAlarm_Hourly` | OWNER 2026-07-23: no separate PIPELINE FAIL/OK mails. `gmail_alarm.py` remains only as the shared SMTP helper for the 06:00 MorningBriefing, the Friday source-access backlog, and reboot diagnostics. |

## BOOTSTRAP — factory autostart (not in any manifest list)

| Task | Behaviour |
|---|---|
| `QM_StrategyFarm_FactoryON_AtLogon` | Trigger **AtLogon of `qm-admin`** (+30s), **Interactive**, **RunLevel=Highest** (skips the self-elevate UAC prompt). Runs `Factory_ON.ps1 -NoPause`. Paired with **autologon** (Sysinternals, `C:\Tools\Autologon`): the console session is created at boot, so this fires ~once per boot and brings the visible MT5 factory up independent of OWNER's (mobile) RDP connection. Added 2026-06-02. **Not** in FACTORY/AI/ALWAYS_ON/ENFORCE_DISABLED lists → Factory OFF does not tear it down. Full runbook: `FACTORY_AUTOLOGON_2026-06-02.md`. |
| `QM_StrategyFarm_FactoryWatchdog_15min` | Historical name; actually every **5 min**, **SYSTEM**, **RunLevel=Highest**. Runs `factory_watchdog.ps1`: detects worker/dispatch/session failures and delegates interactive recovery to the sanctioned qm-admin tasks. On confirmed total session loss it stages `reboot_diagnostic_pending.json` with queue/resource evidence before the controlled reboot. It never sends mail directly; the separate delayed startup diagnostic task uses that verified marker when present and otherwise classifies persistent Windows reboot events, once per boot. Respects OWNER ON/OFF and never launches factory terminals from session 0. Logs to `D:\QM\reports\state\factory_watchdog.jsonl`. **Not** in any manifest list → Factory OFF disables it as a resurrection-vector task. |
| `QM_GoogleDrive_AtLogon` | Trigger **AtLogon of `qm-admin`**, **Interactive**, RunLevel=Limited. Runs `scripts/start_google_drive.ps1` (finds the newest `Drive File Stream\<ver>\GoogleDriveFS.exe` and launches it; idempotent — no-ops if already running). **Why:** Drive's own HKCU Run-key autostart is held back in a headless auto-logon session until an RDP client connects, so the **G: vault mount was missing after a reboot** until OWNER logged in (observed 2026-06-07: boot 02:31, Drive only up 12:44 on RDP connect). This task fires at the boot auto-logon like `FactoryON_AtLogon`, mounting G: independent of RDP. Added 2026-06-07. **Not** in any manifest list. Real validation = next reboot. |

## DECOMMISSIONED — DELETED 2026-06-01 (OWNER-approved)

42 legacy tasks were unregistered from Task Scheduler on 2026-06-01 (`Unregister-ScheduledTask`,
all verified Disabled first). The QM task count dropped 61 → 18. Three groups deleted:

- **Obsolete pre-strategy-farm orchestration tasks (23)** (all legacy integration roots removed; selected roster): `Backup_Daily_0215`,
  `Class2ExecutionPolicySentinel_60min`, `DailyStatusMail`, `DashboardRender_Hourly`,
  `DriveGitExclusion_15min`, `DWX_WS30Gate_15min`, `InfraHealthCheck_5min`,
  `KanbanArchive_Daily_2300`, `PublicSnapshot_Export_Hourly`,
  `PublicSnapshot_Health_15min`, `QUA1006/1016/1023_OpsCycle`, `QUA207_RuntimeHeartbeat`,
  `QUA774_ExternalUnblock{OpsSuite,Status}`, `QUA945_BlockedHeartbeat`, `QUA95_{BlockerRefresh,TaskHealth}`,
  `RecoveryOrphans_Cleanup_Daily_0310`, `RuntimeHealthScan_15min`, `SubscriptionGuardian_5m`.
- **Superseded V5 pre-strategy-farm (15)**: `AggregatorState_1min`, `DWX_HourlyCheck`,
  `GateEvaluator_5min`, `MT5_Worker_T1..T5`, `Phase_Orchestrator`, `PipelineHealth_Watchdog`,
  `PipelineState_Build_Hourly`, `PythonRuntimeHealth_10min`, `Research_Wake_Check`,
  `TokenCostBudgetDailySnapshot_0010`, `TokenCostBudgetHealth_15min`.
- **Paused strategy-farm tasks (4)**: `AutonomousWake_Hourly`, `BoardAdvisor_Hourly`,
  `ClaudeVerify_4h`, `Q08Regen_Resume`. A few have repo install scripts (e.g.
  `install_claude_verify_4h_task.ps1`) and can be re-created by re-running those if ever needed.

> The duplicate 07:00 email task (`QM_StrategyFarm_MorningBrief_0700`) was also
> deleted in the same pass; the single 06:00 MorningBriefing task remains.

## Non-QM tasks (not ours)

`SpaceAgentTask`, `Sqm-Tasks`, `SyspartRepair` — OS/OEM tasks, outside QM scope.
