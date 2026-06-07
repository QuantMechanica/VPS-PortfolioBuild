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
    'QM_StrategyFarm_GmailAlarm_Hourly',      # sanctioned alarm + 06:05 digest
    'QM_MorningBriefing_Vault',               # morning brief (vault) 06:00
    # NOTE: QM_StrategyFarm_MorningBrief_0700 (07:00 email brief) was deleted
    # 2026-06-01 (OWNER: keep vault, drop email). Do not re-add.
    'QM_Public_Snapshot_Hourly',              # quantmechanica.com public JSON
    'QM_StrategyFarm_InboxCleanup_Daily',     # codex_inbox cleanup
    'QM_StrategyFarm_WorktreeClean_4h',       # agent worktree GC
    'QM_WorkItemLogPruner_Daily_0310',        # work_item log pruning
    'QM_StrategyFarm_HourlyMonitor_60min',    # deterministic health triage (auto-fix drift + escalate)
    'QM_StrategyFarm_TesterCachePurge',       # every 3h: purge MT5 tester caches if D:<80GB (interactive, visible-session restart)
    'QM_StrategyFarm_QuotaPull'               # every 5min: headless Codex+Claude limit pull -> quota_snapshot.json (no browser)
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

# --- decommissioned: DELETED 2026-06-01 (OWNER-approved) ------------
#  The 42 Paperclip-era / superseded-V5 / paused-SF tasks previously listed
#  here were unregistered from Task Scheduler on 2026-06-01 (OWNER: "a ja").
#  Kept empty as a marker; the full deleted roster is in
#  docs/ops/SCHEDULED_TASKS_INVENTORY.md. A few had repo install scripts
#  (e.g. install_claude_verify_4h_task.ps1) and can be re-created by re-running
#  those if ever needed.
$QM_DECOMMISSIONED_REFERENCE = @()
