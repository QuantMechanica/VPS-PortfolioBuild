# Audit — Quota / Scheduled Tasks / Routing / Resources (Directive §1, §25, §33)

Read-only snapshot taken 2026-09-15 ~14:26Z on the canonical VPS. Truth precedence per directive §1:
runtime/SQLite/filesystem over Vault/docs. Every row carries an evidence path/command.

## Headline (3 lines)
1. All core factory/orchestration schedulers are Ready/Running; 8 tasks are deliberately Disabled and a handful return non-zero last results (`QM_NewsCalendar_Refresh`, `QM_MailboxSourceIntake_Daily`, `QM_Public_Snapshot_Hourly`, `QM_WorkItemLogPruner_Daily_0310` = 0x1; `QM_EvidenceCohortWatch_Daily_0420` = 0x3 path-not-found; `QM_StrategyFarm_Cockpit_2min` last 0x800710E0).
2. Quota state: Claude throttled (weekly 83%, `CLAUDE_DISABLED.flag` set by quota_governor → router lane `enabled:false`), Codex throttled (weekly 80%, budget-line exceeded, `CODEX_LOW_TOKENS.flag`), agy token EXPIRED (401 → `AGY_LOW_QUOTA.flag`, needs OWNER relogin), Kimi NORMAL (2/40 day, 2/200 week, `local_ledger_only`, no real telemetry, no `KIMI_LOW_QUOTA.flag`).
3. §25/§29/§33 gap confirmed: the Kimi orchestration lane task (`QM_StrategyFarm_KimiOrchestration_15min`) is defined in the installer but NOT installed (default `-IncludeKimi` OFF); Kimi is reachable only via the router when Fable routes to it, not as a continuously-available unattended lane; and there is still no real Kimi quota fetcher (usage_source = `local_ledger_only`), so the 40/200 caps run as hard caps, not the §33 fallback.

---

## Findings

### 1. Scheduled tasks — full inventory
Source: `Get-ScheduledTask | ? TaskName -like 'QM_*'` + `Get-ScheduledTaskInfo` (74 QM tasks). Result-code legend: 0x0 success · 0x1 generic failure/incorrect-function · 0x3 path-not-found · 0x41301 currently running · 0x41303 has-not-run-yet · 0x41306 terminated-by-user · 0x800710E0 operation aborted/refused.

**Running (healthy, 0x41301):** `QM_Live_MT5_SessionSupervisor`, `QM_Orchestrator_Heartbeat_15min`, `QM_StrategyFarm_AgentRouter_5min`, `QM_StrategyFarm_PipelineState`, `QM_StrategyFarm_Pump_5min`, `QM_T_Live_Watchdog`.

**Disabled (8):** `QM_StrategyFarm_FactoryRecycle_Daily`, `QM_StrategyFarm_GmailAlarm_Hourly`, `QM_StrategyFarm_HygieneReboot`, `QM_StrategyFarm_Repair_Hourly`, `QM_StrategyFarm_SourcingIntakeSweep`, `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` (retired per CLAUDE.md drift audit 2026-09-15 — expected), `QM_StrategyFarm_UnreadableLinks_Friday`, `QM_TSCon_Console_OnDisconnect`.

**Non-zero last result (flag for triage):**
- `QM_NewsCalendar_Refresh` last 0x1 (2026-09-15 05:30). News-data freshness is a Hard-Rule-adjacent area — verify the seed at `D:\QM\data\news_calendar` is current.
- `QM_MailboxSourceIntake_Daily` last 0x1 (06:07).
- `QM_Public_Snapshot_Hourly` last 0x1 (14:07).
- `QM_WorkItemLogPruner_Daily_0310` last 0x1 (12:10).
- `QM_EvidenceCohortWatch_Daily_0420` last 0x3 (path-not-found) — script/target path likely moved.
- `QM_StrategyFarm_Cockpit_2min` Running, last result 0x800710E0 (aborted) — cockpit render aborting; relevant to §60 Mission Control rebuild.
- `QM_StrategyFarm_FactoryON_AtLogon` last 0x1 (AtLogon, 2026-09-14) — AtLogon only, not a live wedge.
- `QM_MonthlySleeveCalendar_Refresh` last 0x41303 / 1999 epoch (never run; next 2026-10-01) — monthly cadence, benign.
- Temp tasks terminated (0x41306): `QM_TMP_StaggeredWorkerReload_1700`, `QM_TMP_WebsitePreview_8090`, `QM_TMP_WebsiteRefresh_8091` — stale one-offs, candidates for removal.

Evidence: PowerShell `Get-ScheduledTask`/`Get-ScheduledTaskInfo` transcript in this audit run.

### 2. Kimi lane schedulers — governor present, orchestration NOT installed
- `QM_StrategyFarm_KimiGovernor_15min` = Ready (Plane B pacer runs). Evidence: Get-ScheduledTask.
- `QM_StrategyFarm_KimiOrchestration_15min` = NOT INSTALLED. Evidence: `Get-ScheduledTask -TaskName QM_StrategyFarm_KimiOrchestration_15min` → NOT INSTALLED. The task is defined in `tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1:59` but gated behind `-IncludeKimi` (default OFF, lines 6-10, 56-60). Installed orchestration lanes: Codex, Gemini, Claude only.
- Directive §29 requires Kimi to become continuously AVAILABLE after re-confirming smoke tests. Current state matches the "intentionally left disabled until first campaign validation" that §29 explicitly says is no longer desired.

### 3. Quota / governor state per seat
- **Claude:** weekly used 83.0% at 65.7% elapsed (+17.3pts, projected EOW ~126%), 5h used 72.0%. `CLAUDE_DISABLED.flag` present (set 2026-09-15T10:38:17Z by quota_governor, "engage throttle +12pts"). Router shows `claude enabled:false, max_parallel:0, running:2`. Evidence: `D:/QM/reports/state/quota_governor_state.json`, `D:/QM/strategy_farm/CLAUDE_DISABLED.flag`, `agent_router.py status`.
- **Codex:** weekly used 80.0% at 45.2% elapsed (+34.8pts, projected EOW ~177%), action hold-throttle. Budget line: anchor 64.0% @ 2026-09-13T07:40Z, target_at_reset 92.0%, reset 2026-09-19T08:29Z. `CODEX_LOW_TOKENS.flag` present (set 2026-09-12T16:38Z). Last router gate: `codex_budget_line_exceeded`, allowed:false. Evidence: `quota_governor_state.json`, `codex_budget_line.json`, `CODEX_LOW_TOKENS.flag`, `quota_headroom_summary.json`.
- **agy (gemini lane):** quota UNKNOWN — `agy_quota.json` `ok:false`, HTTP 401 UNAUTHENTICATED on `daily-cloudcode-pa.googleapis.com`, `token_expired:true` (expiry 2026-09-15T10:40+02:00). `AGY_LOW_QUOTA.flag` present (reason `quota_unknown`/`token_expired`, release only on authenticated pull ≥20%). Requires OWNER Antigravity relogin (matches memory). Router still shows gemini `enabled:true` (registry level), but the flag/governor pace it. Evidence: `D:/QM/reports/state/agy_quota.json`, `agy_governor_state.json`, `AGY_LOW_QUOTA.flag`.
- **Kimi:** state NORMAL. counts day 2 / cap 40 (5.0%), week 2 / cap 200 (1.0%). `usage_source: local_ledger_only`. Subscription 2026-09-15 → 2026-10-15. No `KIMI_LOW_QUOTA.flag`. Ledger `D:/QM/reports/state/kimi_usage_ledger.jsonl` = 2 lines (one adapter smoke `kimi-adapter-smoke-20260915` ok, one `fake:test` ok; both `usage:null`). Evidence: `kimi_governor_state.json`, `kimi_usage_ledger.jsonl`.

### 4. Flags present under `D:/QM/strategy_farm/`
`AGY_LOW_QUOTA.flag` (2026-09-15 10:40), `CLAUDE_BURN_AUTHORIZED.flag` (expired 2026-08-24 — stale/inert), `CLAUDE_DISABLED.flag` (2026-09-15 12:38), `CODEX_BURN_AUTHORIZED.flag` (expired 2026-08-25 — stale/inert), `CODEX_LOW_TOKENS.flag` (2026-09-12). Absent: `KIMI_LOW_QUOTA.flag` (Kimi NORMAL). Evidence: `ls D:/QM/strategy_farm/*.flag`.

### 5. Agent registry (code) vs router status vs vault contract
Code source: `tools/strategy_farm/agent_router.py` `DEFAULT_AGENT_REGISTRY` (L561) and `TASK_TYPE_CAPABILITIES` (L114). Router `registry_contract.ok:true, gaps:[]` and `registry_sync.synced:[codex,claude,gemini,kimi,owner]`. The router's live registry, the code, and the vault Annex 2026-09-15 table agree on the Kimi row (enabled, max_parallel 1, cost_rank 12, 12 caps). Vault last-modified 2026-09-15 12:53 and its own note says "Aktueller Code (agent_router.py) gewinnt bei Abweichung." No registry/vault capability drift detected. Evidence: `agent_router.py:561-668, 114-147`; `agent_router.py status`; vault `02 Org/AI Agent Routing and Role Contracts.md` L163-187.
- Minor doc-vs-runtime note: router status reports `claude enabled:false` (quota flag), while the vault table lists claude `enabled: ja`. This is the quota governor's runtime override, not a contract drift — the registry default is enabled.

### 6. Resources
CPU 8 cores / 16 logical; instantaneous load 99.8% (factory saturated — 6 `terminal64.exe` running, expected). RAM 63.1 GB total / 26.9 GB free. Pagefile C:\pagefile.sys allocated 64.0 GB (fixed, matches 2026-09-11 OWNER record), current use 13.6 GB, peak 63.9 GB. Disks: C: 86.9 GB free (18.2%); **D: 61.2 GB free (6.4%)**; G: 82.5 GB free (17.3%). Research venv `D:/QM/research/venv` EXISTS. Evidence: `Win32_OperatingSystem/ComputerSystem/Processor/PageFileUsage/LogicalDisk`, `Get-Process terminal64`, `ls D:/QM/research/venv`.
- **D: free (61.2 GB) is below the Kimi 80-GB research guard** flagged in directive §34 — the guard would block Kimi research now. (Full §34 treatment belongs to the Kimi-phase audit; noted here as a resource constraint.)

---

## Drift table

| Topic | Doc / vault says | Runtime says | Path |
|---|---|---|---|
| Kimi orchestration lane | §29: should be continuously available; installer defines `QM_StrategyFarm_KimiOrchestration_15min` | NOT installed (default `-IncludeKimi` OFF) | `install_agent_orchestration_scheduled_tasks.ps1:56-60`; Get-ScheduledTask |
| Kimi quota source | §31/§32: real UI quota exists, discover & fetch | `usage_source: local_ledger_only`; 40/day 200/week local caps | `kimi_governor_state.json` |
| Kimi local caps | §33: 40/day, 200/week are FALLBACK guardrails, not contract limits | Enforced as active caps (day cap 40, week cap 200) | `kimi_governor_state.json` `caps` |
| Claude lane enabled | Vault table: `enabled: ja` | Router `enabled:false` (CLAUDE_DISABLED quota flag) | vault L166; `agent_router.py status`; `CLAUDE_DISABLED.flag` |
| agy quota | Governor expects authenticated pull | HTTP 401, token_expired → quota_unknown | `agy_quota.json` |
| Kimi D:-space guard | §34: 80 GB guard, not a Hard Rule; reported ~68 GB | D: 61.2 GB free now (< 80 GB → would block) | `Win32_LogicalDisk`; directive §34 |
| News calendar refresh | Task should succeed daily | Last result 0x1 (2026-09-15 05:30) | Get-ScheduledTaskInfo |

---

## Open questions strictly requiring OWNER
- None from this task. agy relogin is an OWNER action already known/tracked (Antigravity OAuth), not a new decision. Kimi subscription upgrade/renewal remains OWNER-only per §30 but nothing here requests it.

---

## Recommended actions for implementing phases (concrete paths)

**Phase C (Kimi operationalization) — §25/§29/§33:**
1. After re-running the Kimi adapter/governor/router smoke, install the Kimi orchestration lane: run `tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1 -IncludeKimi` (registers `QM_StrategyFarm_KimiOrchestration_15min`, MaxSessions=1). Verify with `Get-ScheduledTask`. (§29 continuously-available.)
2. Implement the real Kimi quota fetcher (§31/§32) and set `usage_source` away from `local_ledger_only` in `tools/strategy_farm/kimi_governor.py`; normalized state into `D:/QM/reports/state/` (e.g. a `kimi_quota.json` mirroring `agy_quota.json`). Do NOT read the Kimi credential file.
3. Reclassify the local 40/day-200/week caps as fallback/runaway guardrails once telemetry lands (§33): adjust defaults in `kimi_governor.py` / its config so real capacity wins and local caps only trip on anomaly.
4. Audit/relax the 80-GB D: research guard (§34) — but D: is at 61.2 GB free; either relocate Kimi scratch off D: or free disposable cache before enabling research. Guard location to change lives in the Kimi research stack (see `docs/ops/KIMI_EDGE_DISCOVERY_DESIGN.md`).

**Phase A/D (truth + Mission Control) — task hygiene:**
5. Triage the 0x1/0x3 failing tasks before they poison the snapshot Mission Control reads: `QM_NewsCalendar_Refresh` (news freshness), `QM_EvidenceCohortWatch_Daily_0420` (0x3 path fix), `QM_Public_Snapshot_Hourly`, `QM_MailboxSourceIntake_Daily`, `QM_WorkItemLogPruner_Daily_0310`, and `QM_StrategyFarm_Cockpit_2min` (0x800710E0 abort — relevant to the §60 cockpit rebuild).
6. Remove or re-scope the stale `QM_TMP_*` one-off tasks (terminated 0x41306) so the task board reflects real automation.

**Routing config — no change required:** registry code, router runtime, and vault Annex agree; `registry_contract.ok:true`. Preserve the Kimi authority guard (no code/ops/verdict caps) when installing the orchestration lane.

**Not a defect / expected:** Claude & Codex throttle flags (quota governor pacing toward 2026-09-17/19 resets); `TerminalWorkers_AT_STARTUP` disabled; the 6 running `terminal64.exe` account-level Trades mirroring; `*_BURN_AUTHORIZED` flags are expired/inert.
