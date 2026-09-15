# Kimi integration and Internal Edge Discovery — final implementation report (OWNER directive 2026-09-15, §24.13)

Orchestrator: Claude/Fable, session https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE. Branch `agents/board-advisor`
(canonical checkout C:/QM/repo). Executed as ULTRACODE phases: A audit (7 agents) → B design (6) → finalize (3) → C
implementation (6 worktree slices) → adversarial review (31 agents, 5 lenses + refutation votes) → fix slice → smoke.
Decision record: `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md`; directive verbatim:
`owner_directive_verbatim.md` (this directory).

## 1 · What changed (commits, newest last)

| Commit | Slice | Content |
|---|---|---|
| 1c713f66b8 | A | OWNER decision transcribed; Phase A audit reports (`audit/`) |
| a1c9a3d259, 914d1ddba6 | B | design drafts + adversarial reviews (`design/`); FINAL v1 `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md`, `docs/ops/KIMI_EDGE_DISCOVERY_DESIGN.md`, `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md` |
| 1333826b9b | C1 | `tools/strategy_farm/kimi_adapter.py` (single choke point), `kimi_governor.py`, `config/kimi_adapter.v1.json`, probe battery evidence (`probe_battery/`), 42 tests |
| f978ad0e6d | C5 | `tools/strategy_farm/research/` (observe_projector, research_env + venv guard, search_history_ledger, preregister, mechanization_check, experiment_memory, templates), research venv `D:/QM/research/venv` (uv; pandas, duckdb, scipy, scikit-learn, statsmodels), 25 tests |
| 7725302c24 | C6 | canonical annexes: `CLAUDE.md` (roster, ML scope, quota, drift fixes), Edge Lab charter, operating rules, company audit drift table; Vault pages annexed on G: (Hard Rules HR14 scope, routing contract Kimi row, Company Structure, Research Methodology, Current Operating State) |
| a21517e9dc | C4 | `research_source.py` (mint/resolve/verify/seal/remint), `farmctl` `VALID_SOURCE_TYPES += internal_research` + fail-closed `INTERNAL_SOURCE_UNRESOLVED` in the build-ready gate, `card_intake_prescreen` ML scan scoped to mechanics + internal-source verify, R1/R4 annex in `processes/qb_reputable_source_criteria.md`, worked example `strategy-seeds/sources/QM-RESEARCH-2026-0000/` (retired), 25 tests |
| 4282cea99f | C2 | `agent_router.py` lane `kimi` (cost_rank 12, max_parallel 1, research-only capabilities; task types research_edge_discovery / research_hypothesis / research_critique; flag at sync + route time; routing receipts), `run_agent_orchestration_task.py` kimi branch via the adapter, installer switch `-IncludeKimi` (default OFF), 25 tests |
| 2a46f483b9 | C3 | `agent_chain.py` vendor kimi (gate, run_seat, invariants kimi-creator-never-kimi-critic and never-formatter, routing_reason), critic tables in `config/agent_chain.v1.json`, 22 tests |
| 835089d2fd | ops | `install_kimi_governor_scheduled_task.ps1`, `smoke_receipt.md` |
| 9705000aee | review | review evidence (`review/lenses.json`, `votes.json`) |
| c137c1e476 | fix | review disposition: one JSON flag contract with CONSERVE reaching both planes (integration test), no-shell agent-file for creator/research/formatter roles (`research_ml` only with `allow_shell`), two-scope mutation guard (repo + protected D:/QM and T_Live trees), `schema_mismatch` class, real single-flight concurrency test, lineage.json reconciled, other-lanes-unaffected test, `QM_KIMI=0` in the chain gate, architecture honesty edits |

## 2 · What stayed unchanged (by construction and verified by the review)

Gate code (`dsr_cohort.py`, `terminal_worker.py`, gate manifest v4), verdict/hold/work-item writers, T_Live and
AutoTrading, the Q00–Q17 path, DSR/FDR formulas, external R1 attribution rules (unchanged code path, proven by tests),
historical evidence. No purchase/upgrade/renew code path exists (grep-proven). Backtests never depend on Kimi
(EXHAUSTED/missing → other lanes route as before; test `test_agent_router_kimi_lane.py`).

## 3 · Tests

208 tests green in the Kimi/research/R1 set at c137c1e476 (`test_kimi_adapter`, `test_kimi_governor`,
`test_kimi_quota_flag_contract`, `test_agent_router_kimi_lane`, `test_run_agent_orchestration_kimi`, `test_agent_chain`,
`test_agent_chain_kimi`, `test_research_source`, `test_card_r1_internal_source`, `test_research_observe_projector`,
`test_research_ledgers`, `test_research_mechanization_check`, `test_agent_router`), plus regression suites run per slice
(farmctl build guards, prescreen consumers, orchestration lock/heartbeat, drain/index-table worker suites). Directive §22
matrix: basic invocation, auth failure (simulated with a redirected HOME, real credential untouched), timeout (tree kill),
rate/quota failure, malformed output, schema failure (distinct class), retry exhaustion, unavailable CLI, fallback
provider (chain), CONSERVE/EXHAUSTED end to end (flag contract test), Kimi creator → non-Kimi critic, non-Kimi creator →
Kimi critic, internal source PASS / `author=Kimi` without artifact FAIL / missing hash fails closed, ML-provenance card
not rejected while ML in mechanics still is, restart/recovery (stale lock steal), secret leakage (path-only, scanned
evidence), concurrency (two-thread single-flight), no effect on MT5 workers.

## 4 · Kimi subscription / quota state

Kimi Code CLI 0.43.1, coding-subscription endpoint (USD 99 / month, period recorded 2026-09-15 → 2026-10-15). The CLI
exposes no usage query; state is derived from the local ledger `D:/QM/reports/state/kimi_usage_ledger.jsonl`
(`usage_source: local_ledger_only`, honestly surfaced). Live calls so far: 5 probes + 1 adapter smoke (ledger 2 lines;
probes ran through a scratch ledger). Governor: NORMAL (2/40 day, 2/200 week), flag absent; scheduled task
`QM_StrategyFarm_KimiGovernor_15min` installed 11:5xZ. CONSERVE at 70 % of either cap or near period end; EXHAUSTED at
100 % or two consecutive rate/auth failures or CLI missing; the flag is one JSON contract read by router and chain.

## 5 · Routing capabilities now live

Router lane `kimi` (registry synced by the 5-min router task; cost_rank 12 behind gemini, before codex/claude; max_parallel
1; research/strategy/summary/source_discovery + deep_research, long_context_synthesis, edge_discovery,
cross_experiment_analysis, research_review, research_critic, hypothesis_authoring, ml_research; no code/tests/repo_edit/ops).
New task types routable to it. Chain: Kimi is the second critic candidate for Claude/Codex/agy creators and never critic
of a Kimi creator, never formatter; live through the existing 15-min critique sweep. Orchestration lane task
`QM_StrategyFarm_KimiOrchestration_15min` is NOT installed (installer switch default OFF): Fable starts the first
research campaign explicitly (see §6), then installs the lane.

## 6 · First internal-research capability

Ready to run: `research/observe_projector.py` (read-only dataset with manifest, INFRA vs economic separated),
`search_history_ledger`, `preregister`, `mechanization_check`, `experiment_memory`, templates, research venv. Source
contract implemented end to end: `research_source.py mint` → Kimi authors `source.md` (research role, no shell) →
`agent_chain` critique by a non-Kimi critic → `seal` → card with `source_type: internal_research`, `source: QM-RESEARCH://…`,
`source_hash` → intake verify (prescreen + build gate) → normal Q00–Q17. First campaign proposal (design doc §12): one
OBSERVE dataset + one DISCOVER question answerable from existing evidence, sized to the CPU/disk rule (research jobs refuse
when fleet CPU is above the worker pause threshold or D: < 80 GB; D: is ~68 GB today, so the first campaign waits for the
tester-cache purge or the OWNER's disk decision).

## 7 · Risks

- Research role writes inside its worktree/out_dir (Write/Edit allowed, no shell); guards there are prompt + detection
  (two-scope mutation guard) + orchestrator review, documented as such in the architecture §4.2.
- Auto-updater on the CLI (version recorded per run; a framing change surfaces as `schema_mismatch`).
- OAuth credential is a rolling 15-min token file readable by the profile; ACL tightening is an OWNER/admin step.
- Disk: D: at ~68 GB blocks research campaigns (80 GB rule) until the purge frees space or the OWNER decides.
- The Claude-lane session fan-out defect (one ticket to two sessions) exists independently; ticket 3e0c8b83.

## 8 · Genuinely open OWNER decisions

None required for this directive. Optional: exempt the critic's Codex calls from the weekly budget line
(`codex_budget_line_exempt`) so a non-Claude critic is available for Claude-lane deliveries in throttle weeks (today Kimi
fills that role when NORMAL).

## 9 · Rollback

- Kimi everywhere off: env `QM_KIMI=0` (adapter refuses without spawning; chain gate; lane returns error) — no restart needed.
- Router lane: set `enabled: false` in `DEFAULT_AGENT_REGISTRY['kimi']` or write a JSON `KIMI_LOW_QUOTA.flag` with
  `state: EXHAUSTED`; `git revert 4282cea99f`.
- Chain: `git revert 2a46f483b9` (or remove kimi entries from `config/agent_chain.v1.json`).
- Governor task: `install_kimi_governor_scheduled_task.ps1 -Uninstall`.
- R1 internal source: `git revert a21517e9dc` (external cards unaffected either way).
- Research package: `git revert f978ad0e6d`; venv dir removable.
- Docs: annexes are dated append-only sections (`git revert 7725302c24`; Vault annex sections deletable by the OWNER).
