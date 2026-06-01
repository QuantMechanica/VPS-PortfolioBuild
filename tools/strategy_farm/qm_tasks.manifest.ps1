# =====================================================================
#  QuantMechanica - Canonical Scheduled-Task Manifest (single source of truth)
#  Dot-sourced by Factory_ON.ps1 / Factory_OFF.ps1.
#
#  Categories drive ON/OFF behaviour:
#    FACTORY      - dispatch engine.  ON: enable+start | OFF: stop+disable
#    AI           - agent orchestration. ON: enable+start | OFF: stop+disable
#    ALWAYS_ON    - dashboards/health/alarm/briefs/snapshot/housekeeping.
#                   ON: ENSURE enabled (safety-net) | OFF: LEAVE ALONE
#                   (you still get the morning brief / health / dashboards
#                    even when the factory is OFF — by design).
#    ENFORCE_DISABLED - session-0 respawn hazards that must stay OFF.
#                   ON: force-disable if drifted on | OFF: leave disabled.
#
#  DECOMMISSIONED_REFERENCE is documentation only — Paperclip-era / superseded
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
    'QM_StrategyFarm_ClaudeOrchestration_15min',
    'QM_StrategyFarm_QuotaReceiver'
)

# --- always-on support: ON ensures enabled, OFF leaves running -------
$QM_ALWAYSON_TASKS = @(
    'QM_StrategyFarm_Cockpit_2min',           # cockpit.html every 2 min
    'QM_StrategyFarm_Dashboard_Hourly',       # current/strategies/EA-detail pages
    'QM_StrategyFarm_Health_15min',           # farmctl health
    'QM_StrategyFarm_GmailAlarm_Hourly',      # sanctioned alarm + 06:05 digest
    'QM_StrategyFarm_MorningBrief_0700',      # morning brief (email) 07:00
    'QM_MorningBriefing_Vault',               # morning brief (vault) 06:00
    'QM_Public_Snapshot_Hourly',              # quantmechanica.com public JSON
    'QM_StrategyFarm_InboxCleanup_Daily',     # codex_inbox cleanup
    'QM_StrategyFarm_WorktreeClean_4h',       # agent worktree GC
    'QM_WorkItemLogPruner_Daily_0310'         # work_item log pruning
)

# --- must stay disabled: session-0 daemon respawn hazards -----------
#  Both spawn workers/repair as SYSTEM/session-0 (headless), which the
#  interactive-visible-mode policy (2026-05-23, DL companion) eliminated.
#  Repair now runs ONCE inline in Factory_ON; workers spawn in the user
#  session. If either drifts back to Enabled, ON force-disables it.
$QM_ENFORCE_DISABLED_TASKS = @(
    'QM_StrategyFarm_Repair_Hourly',
    'QM_StrategyFarm_TerminalWorkers_AT_STARTUP'
)

# --- documentation only: NOT toggled by ON/OFF ----------------------
#  Paperclip-era (C:\QM\paperclip\... GUID paths) + superseded V5-pre-farm
#  + intentionally-paused strategy-farm tasks. Left disabled; revive by hand.
$QM_DECOMMISSIONED_REFERENCE = @(
    # Paperclip-era relics
    'QM_Backup_Daily_0215', 'QM_Class2ExecutionPolicySentinel_60min',
    'QM_DailyStatusMail', 'QM_DashboardRender_Hourly', 'QM_DriveGitExclusion_15min',
    'QM_DWX_WS30Gate_15min', 'QM_InfraHealthCheck_5min', 'QM_KanbanArchive_Daily_2300',
    'QM_PaperclipStaleLockWatchdog_15min', 'QM_PublicSnapshot_Export_Hourly',
    'QM_PublicSnapshot_Health_15min', 'QM_QUA1006_OpsCycle_15min',
    'QM_QUA1016_OpsCycle_15min', 'QM_QUA1023_OpsCycle_15min',
    'QM_QUA207_RuntimeHeartbeat_30min', 'QM_QUA774_ExternalUnblockOpsSuite_60min',
    'QM_QUA774_ExternalUnblockStatus_60min', 'QM_QUA945_BlockedHeartbeat_30min',
    'QM_QUA95_BlockerRefresh', 'QM_QUA95_TaskHealth_15min',
    'QM_RecoveryOrphans_Cleanup_Daily_0310', 'QM_RuntimeHealthScan_15min',
    'QM_SubscriptionGuardian_5m',
    # superseded V5 pre-strategy-farm
    'QM_AggregatorState_1min', 'QM_DWX_HourlyCheck', 'QM_GateEvaluator_5min',
    'QM_MT5_Worker_T1', 'QM_MT5_Worker_T2', 'QM_MT5_Worker_T3', 'QM_MT5_Worker_T4',
    'QM_MT5_Worker_T5', 'QM_Phase_Orchestrator', 'QM_PipelineHealth_Watchdog',
    'QM_PipelineState_Build_Hourly', 'QM_PythonRuntimeHealth_10min',
    'QM_Research_Wake_Check', 'QM_TokenCostBudgetDailySnapshot_0010',
    'QM_TokenCostBudgetHealth_15min',
    # intentionally-paused strategy-farm tasks (revive by hand if wanted)
    'QM_StrategyFarm_AutonomousWake_Hourly', 'QM_StrategyFarm_BoardAdvisor_Hourly',
    'QM_StrategyFarm_ClaudeVerify_4h', 'QM_Q08Regen_Resume'
)
