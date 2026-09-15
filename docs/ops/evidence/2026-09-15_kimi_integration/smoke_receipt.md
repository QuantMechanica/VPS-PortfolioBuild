# Kimi smoke-test receipt - 2026-09-15 (directive 24.10)

Generated 2026-09-15T11:12:35Z by Orchestrator Claude from facts on disk; no token value is reproduced anywhere.

| Check | Result | Evidence |
|---|---|---|
| CLI present and version | `0.43.1` at `C:/Users/Administrator/.kimi-code/bin/kimi.exe` | `kimi.exe --version` |
| Credential file present (path only) | True (mtime 2026-09-15T10:39:44+00:00) | `C:/Users/Administrator/.kimi-code/credentials/kimi-code.json` |
| Live probe battery (5 model calls) | reply OK; file read/write via --add-dir; critic agent-file could NOT write; 72 KB pointer prompt; auth-failure simulation exit 1 | `docs/ops/evidence/2026-09-15_kimi_integration/probe_battery/README.md` |
| Adapter end-to-end smoke (live, 1 call) | status ok, text SMOKEOK, ledger line written | ledger lines below |
| Usage ledger lines | 2 (statuses ['ok']) | `D:/QM/reports/state/kimi_usage_ledger.jsonl` |
| Governor state | NORMAL; counts day 2 / week 2; caps {'day': 40, 'week': 200}; usage_source local_ledger_only | `kimi_governor.py status` |
| KIMI_LOW_QUOTA.flag present | False | `D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag` |
| Orchestration lane dry run (no spend) | dry_run_verified True, ok True, model `kimi-code/kimi-for-coding`, quota_state NORMAL, worktree `C:/QM/worktrees/kimi-orchestration-1` created | `D:/QM/strategy_farm/logs/kimi_orchestration_slot1_20260915T111013Z.json` |
| Router lane | `kimi` in DEFAULT_AGENT_REGISTRY (cost_rank 12, max_parallel 1, research-only caps); task types research_edge_discovery / research_hypothesis / research_critique | commit 4282cea99f, test_agent_router_kimi_lane.py |
| Chain vendor | kimi critic for non-kimi creators; kimi creator never kimi critic; never formatter | commit 2a46f483b9, test_agent_chain_kimi.py |
| Scheduled tasks | KimiOrchestration_15min NOT installed (installer switch -IncludeKimi default OFF); KimiGovernor_15min installer written, installed after the review | install_agent_orchestration_scheduled_tasks.ps1, install_kimi_governor_scheduled_task.ps1 |

Ledger lines (ts, task_id, role, capability, model, status, latency_s, cli_version):
- 2026-09-15T10:40:00Z | kimi-adapter-smoke-20260915 | research | research | kimi-code/kimi-for-coding | ok | 17.641 s | 0.43.1
- 2026-09-15T10:59:41Z | fake:test | research | deep_research | kimi-code/kimi-for-coding | ok | 0.0 s | fake
