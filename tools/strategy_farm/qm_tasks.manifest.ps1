# =====================================================================
#  QuantMechanica - Canonical Scheduled-Task Manifest (single source of truth)
#  Dot-sourced by Factory_ON.ps1 / Factory_OFF.ps1.
#
#  Categories drive ON/OFF behaviour:
#    FACTORY      - dispatch engine.  ON: enable+start | OFF: stop+disable
#    AI           - agent orchestration. ON: enable+start | OFF: stop+disable
#    ALWAYS_ON    - dashboards/health/briefs/snapshot/housekeeping.
#                   ON: ENSURE enabled (safety-net) | OFF: LEAVE ALONE
#                   (you still get the morning brief / Friday source report /
#                    reboot diagnostics / health / dashboards
#                    even when the factory is OFF — by design).
#    ENFORCE_DISABLED - unsafe paths and OWNER-disabled channels that must stay OFF.
#                   ON: force-disable if drifted on | OFF: leave disabled.
#
#  DECOMMISSIONED_REFERENCE is documentation only — obsolete orchestration / superseded
#  / intentionally-paused tasks. ON/OFF do NOT toggle these (revival intent is
#  OWNER's call). Full rationale: docs/ops/SCHEDULED_TASKS_INVENTORY.md.
# =====================================================================

# --- managed: dispatch engine ---------------------------------------
$QM_FACTORY_TASKS = @(
    'QM_StrategyFarm_Pump_5min',
    'QM_StrategyFarm_Tick_5min'
)

# --- managed: agent orchestration -----------------------------------
$QM_AI_TASKS = @(
    'QM_StrategyFarm_AgentRouter_5min',
    'QM_StrategyFarm_CodexOrchestration_15min',
    'QM_StrategyFarm_GeminiOrchestration_15min',
    'QM_StrategyFarm_ClaudeOrchestration_15min'
    # QM_StrategyFarm_QuotaReceiver removed 2026-06-07: the Tampermonkey
    # receiver+browser path is superseded by QM_StrategyFarm_QuotaPull (headless
    # API pull, ALWAYS_ON below). Receiver was never actually registered.
)

# --- always-on support: ON ensures enabled, OFF leaves running -------
$QM_ALWAYSON_TASKS = @(
    'QM_StrategyFarm_Cockpit_2min',           # cockpit.html every 2 min
    'QM_StrategyFarm_Dashboard_Hourly',       # current/strategies/EA-detail pages
    'QM_StrategyFarm_Health_15min',           # farmctl health
    'QM_MorningBriefing_Vault',               # morning brief (vault) 06:00
    'QM_StrategyFarm_UnreadableLinks_Friday', # OWNER source-access backlog mail Friday 06:30
    'QM_StrategyFarm_MailboxSourceIntake_Daily', # info@ source extraction + authenticated triage 06:07
    'QM_StrategyFarm_RebootDiagnostic_AtStartup', # one deduplicated cause/recovery mail per Windows boot
    # NOTE: duplicate QM_StrategyFarm_MorningBrief_0700 was deleted. The retained
    # 06:00 task sends the one MorningBriefing mail and writes the vault archive.
    'QM_Public_Snapshot_Hourly',              # quantmechanica.com public JSON
    'QM_StrategyFarm_InboxCleanup_Daily',     # codex_inbox cleanup
    'QM_StrategyFarm_WorktreeClean_4h',       # agent worktree GC
    'QM_WorkItemLogPruner_Daily_0310',        # work_item log pruning
    'QM_StrategyFarm_HourlyMonitor_60min',    # deterministic health triage (auto-fix drift + escalate)
    'QM_StrategyFarm_TesterCachePurge',       # every 20min: purge MT5 tester caches if D:<150GB; preserve captured Factory ON/OFF state
    'QM_StrategyFarm_QuotaPull',              # every 5min: headless Codex+Claude limit pull -> quota_snapshot.json (no browser)
    'QM_StrategyFarm_QuotaGovernor',          # every 15min: weekly-pace throttle (CODEX_LOW_TOKENS/CLAUDE_DISABLED + lane-boost); reads quota_snapshot.json
    'QM_StrategyFarm_PortfolioReport',        # every 6h: R-064-5 portfolio re-fit report on the stress-gated robust pool (Q08 FAIL_SOFT) -> portfolio_latest.json
    'QM_T_Live_AtLogon',                      # DXZ live MT5 interactive autostart
    'QM_FTMO_AtLogon',                        # FTMO live/trial MT5 interactive autostart
    'QM_Live_MT5_SessionSupervisor',          # resident per-session recovery during RDP disconnect
    'QM_T_Live_Watchdog',                     # both live terminals + session recovery, SYSTEM/1min
    'QM_StrategyFarm_LiveBookPulse',          # DXZ read-only live telemetry
    'QM_FTMO_TrialPulse',                     # FTMO read-only live telemetry
    'QM_StrategyFarm_LsmHealthProbe',          # session-manager health evidence
    'QM_StrategyFarm_SilentFailureMonitor'    # alarm-sidecar producer
)

# --- must stay disabled: unsafe paths + explicit OWNER opt-outs -----
#  The first two spawn workers/repair as SYSTEM/session-0 (headless), which the
#  interactive-visible-mode policy (2026-05-23, DL companion) eliminated.
#  Repair now runs ONCE inline in Factory_ON; workers spawn in the user
#  session. The tscon task can tear down the interactive desktop, while the
#  legacy hygiene task can force-reboot healthy live MT5 without the new live
#  recovery guards. If any drifts back to Enabled, ON force-disables it.
$QM_ENFORCE_DISABLED_TASKS = @(
    'QM_StrategyFarm_Repair_Hourly',
    'QM_StrategyFarm_TerminalWorkers_AT_STARTUP',
    'QM_TSCon_Console_OnDisconnect',           # proven session-teardown race (2026-07-21)
    'QM_StrategyFarm_HygieneReboot',           # unguarded reboot path; keep OFF until hardened
    'QM_StrategyFarm_GmailAlarm_Hourly'        # OWNER 2026-07-23: no separate PIPELINE FAIL/OK mail; morning brief remains
)

# --- decommissioned: DELETED 2026-06-01 (OWNER-approved) ------------
#  The 42 obsolete-orchestration / superseded-V5 / paused-SF tasks previously listed
#  here were unregistered from Task Scheduler on 2026-06-01 (OWNER: "a ja").
#  Kept empty as a marker; the full deleted roster is in
#  docs/ops/SCHEDULED_TASKS_INVENTORY.md. A few had repo install scripts
#  (e.g. install_claude_verify_4h_task.ps1) and can be re-created by re-running
#  those if ever needed.
$QM_DECOMMISSIONED_REFERENCE = @()
