## Architecture Drift Report — QuantMechanica V5 (2026-09-15, read-only audit)

Scope: CLAUDE.md (C:/QM/repo), the Vault routing contract, docs/ops/COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md and docs/ops/OPERATING_RULES_2026-07-03.md, compared against registered scheduled tasks, the last-48h orchestration logs, quota flags/state, the agent registry, the gate manifest, and a 14-path tool spot-check.

**Headline: the hard-bounded contracts (gate names, tool paths, gemini→agy binding, Claude=Sonnet) are faithful. Drift is concentrated in (a) one reboot-recovery instruction pointing at a disabled task, (b) a tester-purge threshold, (c) the agy lane's role, and (d) several new control-plane mechanisms that never made it into CLAUDE.md.**

---

### Drift Table

| # | Doc claim | Runtime reality | Evidence | Severity | Recommended doc fix |
|---|-----------|-----------------|----------|----------|---------------------|
| 1 | CLAUDE.md (Infrastructure Constants): "After a VPS reboot, check the `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` scheduled task." | That task is **Disabled** (LastRun 23.05.2026). Workers now come up via `QM_StrategyFarm_FactoryON_AtLogon` → `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause`. | `Get-ScheduledTask`: `QM_StrategyFarm_TerminalWorkers_AT_STARTUP State=Disabled`; action ARG = `start_terminal_workers.py --repo-root C:\QM\repo …`. `QM_StrategyFarm_FactoryON_AtLogon` action = `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause` (LastResult 1). | **HIGH** | Replace the reboot-check pointer with `QM_StrategyFarm_FactoryON_AtLogon` / `Factory_ON.ps1`; note TerminalWorkers_AT_STARTUP is retired/disabled. |
| 2 | CLAUDE.md + QUOTA_GOVERNOR runbook: tester purge "no-op ≥150GB free; LowWater 80→150 seit 2026-07-21", every 10min. | 10-min cadence correct, but live task runs **`-LowWaterGB 60`**. | `QM_StrategyFarm_TesterCachePurge` action ARG `-LowWaterGB 60`; repetition `Interval=PT10M`. | **MEDIUM** | Update CLAUDE.md and the runbook to LowWater **60 GB** (or reconcile if 60 was unintended). |
| 3 | CLAUDE.md: "Antigravity (agy) — broad research, source discovery, strategy-idea mechanization." MEMORY: "agy=NUR BACKUP, halluziniert." | The live registry gemini lane still declares `code, tests, repo_edit`; the orchestration prompt template explicitly allows agy to draft code. | `agent_router.py` `DEFAULT_AGENT_REGISTRY['gemini'].capabilities = ['code','tests','repo_edit','research','strategy','source_discovery']` (comment: "Whether code/tests/repo_edit belong on this lane is a SEPARATE OWNER decision … Leave the rest exactly as-is"); `COMPANY_AUDIT_LIVE_SOURCES` L273-274 "Gemini may draft code, but Codex review is mandatory". | **MEDIUM** | Either trim the gemini lane caps (pending OWNER decision) or add a CLAUDE.md note that the registry still grants code caps but they are deprecated/backup-only. |
| 4 | CLAUDE.md quota section names only `quota_governor.py` (+ `agy_governor.py`) as the spend authorities. | A separate **Codex weekly budget line** (`codex_budget_line.py`) + **`codex_fleet_pacer.py`** pace the Codex lane, on their own task. | `codex_budget_line.py` header "OWNER 2026-09-13 … Codex weekly budget line"; `QM_StrategyFarm_CodexFleetPacer` action runs `codex_fleet_pacer.py` (PT5M). | **MEDIUM** | Add the Codex budget line/fleet pacer to the Quota Governance section (with rollback switch `QM_CODEX_BUDGET_LINE=0`). |
| 5 | No mention of an automated cross-vendor critic outside EA builds. | `agent_chain.py` runs a Creator→Critic→Formatter chain over pending REVIEW rows every 15min. | `agent_chain.py` header "OWNER 2026-09-15 … cross-model by construction"; `QM_StrategyFarm_AgentChain_Critique_15min` runs `agent_chain.py critique-pending --apply --max 2` (PT15M). | **MEDIUM** | Document the agent_chain critique sweep in the Capability Router / Orchestrator Mandate section. |
| 6 | Gate naming (hard-bounded). | **No drift** — all 18 names Q00–Q17 in the active manifest match CLAUDE.md and the COMPANY_AUDIT 2026-09-13 addendum verbatim. | `gate_manifest.v4.json` dump (Q00 Research Intake … Q17 Live Burn-In DXZ). | none | — (COMPANY_AUDIT still carries the stale "Q00 through Q13" body text above its own addendum; a cleanup would help but the addendum supersedes it.) |
| 7 | Tool paths in CLAUDE.md/OPERATING_RULES. | **No drift** — 14/14 spot-checked paths exist. | file-existence loop (all OK). | none | — |
| 8 | CLAUDE.md: gemini lane executes via agy CLI, gemini-cli dead. | **No drift** — confirmed in code. | `run_agent_orchestration_task.py` L96-106, L161-173. | none | — |
| 9 | CLAUDE.md: headless Claude builds run Sonnet. | **No drift** — model_contract=sonnet. | `claude_orchestration_slot1_20260915T083001Z.json` model='sonnet'. | none | — |

---

### Lanes actually running (last 48h)

- **Claude (Sonnet)** — active. `claude_orchestration_slot1/slot2_20260915T083001Z.json`: backend `claude`, `--model sonnet`, `selection_reason=sonnet_default_deliberate_opus_only`, both slots ran to rc=0 (slot1 push rejected non-fast-forward — a worktree-behind symptom, not a lane failure). Runs 04:30Z, 05:30Z, 07:30Z, 08:30Z, and 2026-09-14 22:00/22:15/23:45Z.
- **Codex** — active. `codex_orchestration_slot1_20260915T011502Z.json`: backend `codex`, model `gpt-5.6-sol` (tier `sol`; ladder sol→terra→luna→gpt55→gpt54→gpt54mini), reasoning_effort `max`, enforcement mode `observe`.
- **gemini/agy** — scheduled (`QM_StrategyFarm_GeminiOrchestration_15min`, LastResult 0) but currently **auth-degraded**: `agy_quota.json` HTTP 401 `token_expired`, `AGY_LOW_QUOTA.flag` set `reason=quota_unknown`.

### Quota flags & state (live)

- `D:/QM/strategy_farm/`: `AGY_LOW_QUOTA.flag` (token_expired), `CODEX_LOW_TOKENS.flag` (managed_by quota_governor, set 2026-09-12), `CLAUDE_BURN_AUTHORIZED.flag` (expired 2026-08-24), `CODEX_BURN_AUTHORIZED.flag` (expired 2026-08-25). No `CLAUDE_DISABLED.flag` present (governor references it at `quota_governor.py:54`; absence = claude not throttled — consistent).
- `quota_governor_state.json`: codex used 80% / +36.5pts ahead → `action=hold` (throttle sustained); claude used 71% / +6.9pts → `action=noop`, `parallel.claude.boosted=true`.

### Undocumented-but-live mechanisms (not in CLAUDE.md)

1. **agent_chain cross-vendor critique sweep** — `agent_chain.py critique-pending --apply --max 2`, task `QM_StrategyFarm_AgentChain_Critique_15min` (OWNER 2026-09-15). Read-only critic seats; writes receipts under `D:/QM/strategy_farm/state/agent_chain/`.
2. **Codex weekly budget line + fleet pacer** — `codex_budget_line.py` (OWNER 2026-09-13) + `codex_fleet_pacer.py`, task `QM_StrategyFarm_CodexFleetPacer` (PT5M). State `D:/QM/reports/state/codex_budget_line.json`; rollback `QM_CODEX_BUDGET_LINE=0`.
3. **quota_pull.py** — task `QM_StrategyFarm_QuotaPull` feeds the governor; not named in the quota section.
4. **Codex model-tier ladder** — sol/terra/luna/gpt55/gpt54/gpt54mini with per-tier budgets and `observe` enforcement (committed_ledger_booking), evidenced in codex orch model_contract; CLAUDE.md describes no Codex model tiers.
5. **Dry-run / watchdog tasks** — `QM_StrategyFarm_GovernorDryRunWatch`, `QM_StrategyFarm_Q10Breaker_DryRun_15min`, `QM_StrategyFarm_SilentFailureMonitor`, `QM_StrategyFarm_ReconcileOrphans_Hourly`, `QM_StrategyFarm_WorkerDedupe`, `QM_StrategyFarm_TaxonomyMaterialize_Hourly` — live but uncatalogued (CLAUDE.md is not a full task catalog, so LOW priority to document).

### Runtime health note (tangential to drift)

Non-zero `LastTaskResult` observed on: `QM_NewsCalendar_Refresh`=1, `QM_StrategyFarm_MailboxSourceIntake_Daily`=1, `QM_Public_Snapshot_Hourly`=1, `QM_EvidenceCohortWatch_Daily_0420`=3, `QM_WorkItemLogPruner_Daily_0310`=1; `QM_StrategyFarm_Cockpit_2min`/`Pump_5min` show `2147946720` while State=Running (likely stale prior-run code). Running tasks (`Heartbeat`, `Live_MT5_SessionSupervisor`) show `267009`=0x41301 "task currently running" (informational). These are operational signals, not architecture drift — flagged for a separate health pass. UNKNOWN whether the daily failures are persistent.

### Verification method

All facts carry a path+line, a command with its output line, or a SQL/JSON read. Truth precedence applied: live scheduled-task actions and code/JSON state over doc prose. No files were modified; sqlite was not opened (no SQL needed for this scope).