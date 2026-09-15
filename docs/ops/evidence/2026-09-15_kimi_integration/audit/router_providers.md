# Kimi Provider Integration Audit — QuantMechanica V5 strategy_farm

Read-only audit of C:/QM/repo/tools/strategy_farm. Every claim carries a file:line, a DB result, or a scheduled-task listing. Goal: enumerate what must change to add provider kimi with capabilities [deep_research, long_context_synthesis, edge_discovery, cross_experiment_analysis, research_review, research_critic, hypothesis_authoring, ml_research] and no gate/live/deployment/verdict authority.

Baseline: grep for kimi or moonshot in tools/strategy_farm = no matches. Kimi is entirely new.

## 1. Two planes you must touch (do not conflate)

Plane A — deterministic router (agent_router.py + farm_state.sqlite): decides which lane claims a ticket. Selection = capability-subset filter, then ORDER BY cost_rank ASC (agent_router.py:1668-1686). State in agent_registry (synced from DEFAULT_AGENT_REGISTRY) and agent_tasks.

Plane B — execution: two independent spawners — scheduled orchestration (run_agent_orchestration_task.py, per-agent hardcoded branches) and the Creator/Critic/Formatter chain (agent_chain.py + config/agent_chain.v1.json, vendor switch in run_seat). Kimi must be wired into BOTH; they share no code or pacing state.

### DB schema (sqlite3 mode=ro)
Tables: agent_registry, agent_tasks, spawn_leases, router_writer_contract, etc. — no dedicated provider/lane table; the registry row is the lane. agent_tasks columns: id, task_type, state, priority, required_capabilities_json, assigned_agent, budget_class, parent_id, artifact_path, verdict, payload_json, created_at, updated_at, required_skills_json (agent_router.py:766-796). Live rows: codex (…scalpel_mechanization) max5 rank20; claude (…summary,scalpel_mechanization) max3 rank30; gemini (code,tests,repo_edit,research,strategy,source_discovery) max2 rank10; owner (video_analysis,research,strategy,review,summary) max0 rank99 enabled0. Registry writes are DB-trigger gated to the canonical checkout (_registry_writer_authorized = real .git dir :826-833; triggers :936-964) — a kimi row lands only when sync_default_registry runs from C:/QM/repo (the 5-min QM_StrategyFarm_AgentRouter_5min task).

## 2. Capability model — the routability trap
TASK_TYPE_CAPABILITIES (:106-128) is the source of truth for what each task requires (research_strategy: research,strategy; review_strategy: review,strategy; build_ea: code; review_ea: review,code; triage_failure: ops,review; ops_issue: ops,code; agent_learn: research; strategy_mechanize_source: research,strategy,scalpel_mechanization). route_once builds required = column, plus (payload_caps intersect declared-or-governed), plus scalpel, plus (skills intersect declared-or-governed) (:1760-1800); a lane is eligible iff required is a subset of caps (:1678-1680).

Consequence: the 8 kimi caps map to no task_type, so kimi is never selected. Fix by (1) new task_types requiring the caps, (2) payload required_capabilities / required_skills naming them (they gate only because kimi declares them, :1217-1235), or (3) also declaring classic caps (research/strategy/review/summary/source_discovery). _governed_routing_capabilities (:1511-1517) auto-derives from the registry.

### No gate/live/deployment/verdict authority
Enforced by omission: do NOT declare code/ops/repo_edit/scalpel_mechanization; do NOT add kimi to AGENT_TASK_TYPE_LANES (:215-220); verdicts/APPROVED are the orchestrator manual close-review; review_ea is excluded from the generic critic (agent_chain.v1.json critique.skip_task_types); mirror the gemini leave-in-REVIEW/no-self-approve/no-main-advance rule (run_agent_orchestration_task.py:273-274,292-294).

### decision_bound / assigned_agent
assigned_agent = live IN_PROGRESS claim; durable pin = payload.decision_bound_agent (:497, resolved :1128-1175; owner_decision receipt pins default claude :499). A pinned row waits or holds (:1808-1826); malformed pin fails closed. Kimi is a valid pin target once registered. Human-lane hold (owner, _human_lane_holder:1557-1594) is the disabled-lane visible-hold reference; not needed unless a kimi cap is human-gated.

## 3. Pacing — quota state and the router-vs-execution gap
Two disjoint surfaces. Router: disables only claude (sync_default_registry:1072-1074 reads CLAUDE_DISABLED.flag) and the codex/claude weekly gate (GATED_AGENTS is codex and claude, quota_spawn_gate.py:36, applied _quota_gate_decision:1700); it never reads AGY_LOW_QUOTA. Execution: agent_chain.vendor_gate (:172-214) reads claude_disabled/codex_low_tokens/codex_budget_line/agy_low_quota; the harvest honors AGY_LOW_QUOTA. So KIMI_LOW_QUOTA alone paces the chain but not the router — add a router-side KIMI_DISABLED (claude pattern) or GATED_AGENTS membership.

### Recommended KIMI quota state (agy-style)
agy_governor.py template: pull, compare FLOOR_PCT (:39), ownership-tracked flag with MANAGED_BY marker (_set_flag:79-90, _clear_flag:93-102, reclaim-by-marker quota_governor.py:279-282). Map NORMAL to no flag; CONSERVE to a soft marker or state/kimi_parallel.txt (cf. boost files quota_governor.py:326-356); EXHAUSTED to write D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag (ownership in D:/QM/reports/state/kimi_governor_state.json). Weekly-pace alternative: quota_governor.py (FLAGS:52-55, _decide:215-226, BURN_FLAGS:181-184). Finer per-spawn: codex_budget_line.py (ENV_SWITCH QM_CODEX_BUDGET_LINE, enabled:40, evaluated vendor_gate:193-205). New files: kimi_governor.py plus kimi_quota.py; a QM_StrategyFarm_KimiGovernor task (mirror QM_StrategyFarm_AgyGovernor).

## 4. agent_chain — vendor resolution, kimi as creator/critic
Config (agent_chain.v1.json): vendors are claude/codex/agy; roles.critic.cross_vendor_required true plus by_creator_vendor tables (agy always last, branded hallucinates, never sole critic unless allow_agy); gates. Code: VENDOR_ALIASES (:68), vendor_gate (:172-214, unknown to fail closed), open_critic_seats (:245-270, cross = seat.vendor not equal creator_vendor :267), run_seat switch (:637-648, unknown to ChainError), _model_id/resolve_cli/seat_env (:352-393). Receipt at D:/QM/strategy_farm/state/agent_chain/CHAINID.json.

Kimi: (1) config vendors.kimi plus gates.kimi_low_quota_flag; (2) by_creator_vendor.kimi listing only non-kimi seats (satisfies Kimi-creator to non-Kimi-critic); (3) add kimi rows into claude/codex/agy/unknown creator tables so kimi can critique others; (4) code: VENDOR_ALIASES (moonshot/k2 to kimi), vendor_gate branch, resolve_cli/seat_env/_model_id, run_seat elif, run_kimi (mirror _run_agy:552-587 if ConPTY/no-stdin, else _run_claude:421+). Critique task QM_StrategyFarm_AgentChain_Critique_15min runs agent_chain.py critique-pending --apply --max 2 via the console helper as qm-admin.

## 5. run_agent_orchestration_task.py — scheduled lane
Per-agent branches: resolve_cli:155-179; agent_env:182-203; build_prompt:206-295 (gemini skips G: :211-222); command_for:408-498 (codex exec/-m/-c; gemini via agy_conpty_run.py ConPTY, no stdin, print-timeout, -p pointer :439-485; claude -p --model --add-dir); headless_model_contract:501-544; run_agent_slot cwd shared-repo for gemini else worktree (:708-724), shell true unless gemini (:885), codex-only managed lease (:889-909), result write (:987); main choices (:1906). Add a kimi branch to each plus KIMI_BIN/KIMI_HEADLESS_MODEL constants plus choices tuple. The stdin/TTY choice is load-bearing (wrong to hang to timeout).

## 6. Observability to mirror
Orchestration result JSON under D:/QM/strategy_farm/logs/ (:987): agent, execution_backend, model_contract, slot, dry_run, prompt_path, live_log, command, cwd, worktree, started_at, pid, returncode, ok, push, finished_at (codex-only lease_id, model_window_ledger) plus the prompt md and live.log siblings. Lane heartbeat state/lane_AGENT_heartbeat.json (_lane_heartbeat_stale:1483-1496; stale over 2h de-lists). Lease events (_record_lease_event): routing_awaiting_ variants, quota_gate_blocked, etc. Chain receipt qm.agent-chain.receipt.v1 (:66, fields :746-908): chain_id, kind, status, stages array, seat_trace (creator/critic/formatter), critic_verdict, finding_counts, critic_fallback_used, critic_seat_final, scope_drift, plan, input_bindings, generated_at_utc, receipt_path; per stage a prompt.md, a vendor log, and a vendor answer.md. spawn_leases/managed_codex are codex-only; a plain kimi lane uses the file lock (acquire_lock).

## 7. Tests
test_agent_router.py (selection, cost_rank, routability), test_agent_chain.py (kimi vendor plus creator/non-kimi-critic invariant), test_quota_spawn_gate.py (only if GATED), test_agy_governor.py to new test_kimi_governor.py, test_antigravity_backend_contract.py to new kimi backend-contract test, test_agent_selection_skill_contract.py, test_agent_orchestration_lock.py.

## 8. Scheduled tasks
Current: AgentRouter_5min (Running), CodexOrchestration/GeminiOrchestration/ClaudeOrchestration_15min (Ready), AgentChain_Critique_15min (Ready), AgyGovernor (Ready), QuotaGovernor/QuotaPull (Ready). Add: kimi row in install_agent_orchestration_scheduled_tasks.ps1 definitions (:42-46) to QM_StrategyFarm_KimiOrchestration_15min; and QM_StrategyFarm_KimiGovernor. Use the run_in_console_session.ps1 helper branch (:68-82) iff kimi auth is DPAPI/Credential-Manager bound; else the plain SYSTEM branch (:83-91).

## 9. Risks (ranked)
1. Auth token race (Codex class) — keep MaxSessions at 1 unless auth isolated (install ps1:31-41).
2. Session-0 vs console — hop to qm-admin console if auth needs operator context (agy_governor.py:14-16, install ps1:68-82).
3. stdin/TTY (agy class) — ConPTY+pointer vs stdin-file (run_agent_orchestration_task.py:439-485,879-888).
4. Router-vs-execution pacing gap — KIMI_LOW_QUOTA alone does not stop the router (agent_router.py:1072-1074).
5. Unroutable-capability trap — wire the 8 caps into task_types/payload/skills (:106-128,1770-1800).
6. Verdict/authority leakage — keep kimi off code/ops/scalpel, out of AGENT_TASK_TYPE_LANES, REVIEW-terminal.
7. Cross-vendor rule regression — never list a kimi seat inside by_creator_vendor.kimi (agent_chain.py:258-269).
8. Registry sync latency — kimi applies only after the canonical 5-min router task runs sync_default_registry (:826-833,936-964).