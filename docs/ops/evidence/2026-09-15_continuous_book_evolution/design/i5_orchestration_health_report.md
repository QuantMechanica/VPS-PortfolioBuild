# Slice i5_orchestration_health — implementation report

Follow-up directive §18 (AI orchestration health), §16 (Kimi runs), §15 (Kimi telemetry final
state), §17 (research capacity final state); master §35 (Claude-lane fan-out). Worktree base
`8a3ba58fea` on `agents/board-advisor`. Date 2026-09-15.

## Summary
Measured the live orchestration health from runtime evidence, built a deterministic read-model +
Mission Control wiring for it, and produced a gated stale-task disposition plan + applier. The
one provable defect in scope — a same-vendor critic fallback that silently reduced review
independence — was already surfaced in the agent_chain receipt; it is now also surfaced in
Mission Control (the fix). No gate, verdict, qualification, T_Live, farm-DB write, or scheduled
task was touched.

## Deliverables
1. **MEASURED report** `docs/ops/evidence/2026-09-15_continuous_book_evolution/ORCHESTRATION_HEALTH_2026-09-15.md`
   — per-lane state, 7-day throughput (with the `updated_at`-proxy + 2026-09-12 bulk-touch
   caveats), stale tasks (2 IN_PROGRESS beyond TTL, 308 TODO >14d), double-claim/fan-out state,
   critic independence (4/5 same-vendor), quota-flag time-on, routing (40/40), Kimi telemetry
   final state, §16 checklist (all YES), research guard final state.
2. **Read-model** `tools/strategy_farm/orchestration_health_readmodel.py` →
   `D:/QM/reports/state/orchestration_health.json` (`qm.orchestration-health/v1`), deterministic
   (content is a pure function of inputs; only `generated_at_utc` + age windows use an injectable
   `now`), read-only sources, EVIDENCE_MISSING-tolerant. Wired into the existing 15-min read-model
   runner (`book_evolution_runner.py _default_state_builds`) — **no new scheduled task**. Exposed
   in Mission Control: `mission_control_v2_data.build_contract` binds `orchestration_health`
   verbatim via new `load_orchestration_health` (schema property added, EVIDENCE_MISSING tolerant).
3. **Stale-task disposition PLAN** `docs/ops/evidence/2026-09-15_continuous_book_evolution/STALE_TASKS_DISPOSITION_2026-09-15.md`
   + CSV `stale_task_disposition_plan_2026-09-15.csv` + dry-run applier
   `tools/strategy_farm/session_tools/apply_stale_task_dispositions.py` (classifier is read-only;
   `--apply` uses `agent_router.py update-task`; build_ea candidate rows gated behind
   `--allow-candidate-park` / `--allow-candidate-close`). Classifier output: PARK 275 / KEEP 59 /
   COMMISSION 49 / CLOSE 16.
4. **Defect fix (item 4):** the quota-driven same-vendor critic fallback (`cross_vendor=false`) —
   verified already in the receipt (`plan.critic.cross_vendor`, per-stage `cross_vendor`, the
   same-vendor note) and now surfaced in Mission Control via the read-model
   (`critic_chain.cross_vendor_false / same_vendor_share / independence_degraded` + health flag
   `critic_same_vendor:N/M`). No `agent_chain` code change needed (it already records the truth).

## Files changed / added
- A `tools/strategy_farm/orchestration_health_readmodel.py`
- A `tools/strategy_farm/session_tools/apply_stale_task_dispositions.py`
- M `tools/strategy_farm/mission_control_v2_data.py` (path const + `load_orchestration_health` +
  build_contract binding + schema property)
- M `tools/strategy_farm/book_evolution_runner.py` (`_default_state_builds` += orchestration_health)
- A `tools/strategy_farm/tests/test_orchestration_health_readmodel.py`
- A `tools/strategy_farm/tests/test_stale_task_dispositions.py`
- M `tools/strategy_farm/tests/test_mission_control_v2_data.py` (+ orchestration_health present/absent)
- A `docs/ops/evidence/2026-09-15_continuous_book_evolution/ORCHESTRATION_HEALTH_2026-09-15.md`
- A `docs/ops/evidence/2026-09-15_continuous_book_evolution/STALE_TASKS_DISPOSITION_2026-09-15.md`
- A `docs/ops/evidence/2026-09-15_continuous_book_evolution/stale_task_disposition_plan_2026-09-15.csv`
- A `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/i5_orchestration_health_report.md`

## Contracts changed
- New read-model schema `qm.orchestration-health/v1` (`orchestration_health.json`).
- `qm.mission_control.v2`: new OPTIONAL, permissive top-level property `orchestration_health`
  (bound verbatim; not in `required`; EVIDENCE_MISSING tolerant — validation stays green when the
  read-model is absent). No existing key changed.
- New CLI contracts: `orchestration_health_readmodel.py build` and
  `apply_stale_task_dispositions.py --classify/--plan/--apply` (with candidate opt-in guards).
- No gate threshold, verdict semantic, qualification criterion, or farm-DB write path changed.

## Tests + summary line
`python -X utf8 -m pytest tools/strategy_farm/tests/test_orchestration_health_readmodel.py
tools/strategy_farm/tests/test_stale_task_dispositions.py
tools/strategy_farm/tests/test_mission_control_v2_data.py
tools/strategy_farm/tests/test_factory_bottleneck_readmodel.py
tools/strategy_farm/tests/test_book_evolution_runner.py -q` → **55 passed in 6.09s**.
Coverage: read-model task-states/throughput/stale/double-claim/critic-independence/routing/
quota-flags/kimi/health-rollup/determinism/db-missing/receipts-missing (10);
disposition classifier rules + candidate guard opt-in + router command shapes (4); MC
orchestration_health present + absent (2); plus the pre-existing MC + bottleneck + runner suites.
`py_compile` clean on all changed modules.

## Runtime artifacts written (counts)
- `D:/QM/reports/state/orchestration_health.json` (`qm.orchestration-health/v1`): health AMBER;
  routing 40/40; critic completed 5, cross_vendor_false 4; stale IN_PROGRESS 2, stale TODO 308;
  kimi usage_source managed_usage_endpoint; research allowed true (46.3 GB scratch).
- `docs/ops/evidence/.../stale_task_disposition_plan_2026-09-15.csv`: 399 rows classified
  (PARK 275 / KEEP 59 / COMMISSION 49 / CLOSE 16).
No farm-DB write; no scheduled task registered; T_Live untouched; MT5 workers unaffected.

## Headline numbers (for the final audit)
- Routing correctness: 40/40 OK / 0 mismatch (`orchestration_health.json:routing`).
- Critic independence: 4/5 recent critiques same-vendor (`critic_chain.cross_vendor_false=4`,
  `completed=5`, `same_vendor_share=0.80`) — cause: Codex + agy critic lanes quota-gated.
- Stale: 2 IN_PROGRESS beyond 30-min TTL; 308/326 TODO older than 14 days; 73 BLOCKED (69 aged).
- Fan-out fix: landed at HEAD, 0 `agent_task_exec:*` live rows (lane quota-disabled + max-sessions 1),
  31 router `agent_task:*` NULL-owner (by design); no post-fix claude run yet.
- Kimi telemetry: `usage_source=managed_usage_endpoint`, refresh_calls=1, last_ok reuse present (§15 done).
- Kimi ran: QM-RESEARCH-2026-0001/0002 sealed; §16 checklist all YES (critic Fable-inline caveat).
- Research guard: allowed=true, scratch C: 46.3 GB free / 20 GB floor (§17 unblocked).

## Rollback
- Revert the two new modules + the four edits (mc/runner + two test edits). The read-model file
  and the plan CSV are additive artifacts under `D:/QM` / evidence and can be deleted. The MC
  `orchestration_health` key is optional, so removing the binding leaves the contract valid.
- Disposition applier is inert without `--apply`; any state it moves is reversible via
  `agent_router.py update-task` / re-enqueue (verdicts are appended, never deleted).

## NOT done (with reasons)
- **Did not register or modify any scheduled task.** The read-model is *wired* into the existing
  `QM_StrategyFarm_BookEvolutionReadModels_15min` runner (code), but the auditor never registers
  tasks; the orchestrator re-runs `install_book_evolution_scheduled_tasks.ps1` if a fresh task
  action is wanted (not required — the runner picks up the new build automatically).
- **Did not apply any disposition.** Only `--classify` (read-only) was run. The 275-row legacy
  build_ea PARK cohort needs an orchestrator/OWNER cohort decision (candidate rows = ROT-adjacent);
  the applier gates it behind `--allow-candidate-park`.
- **Did not fix `agent_chain` cross-vendor logic** — it already records `cross_vendor` truthfully;
  the only gap (not visible in Mission Control) is fixed by the read-model + MC wiring.
- **Could not demonstrate a live post-fix zero-collision claude run** — the claude lane is
  quota-disabled and at `--max-sessions 1`, so it has not spawned under the exec-lease scheme; the
  demonstration is the orchestrator's first exit criterion when re-raising to `--max-sessions 3`.

## Commands for the orchestrator
```powershell
cd C:/QM/repo
# build the read-model on demand (already wired into the 15-min runner)
python tools/strategy_farm/orchestration_health_readmodel.py build --stdout
# reconcile the two collided IN_PROGRESS rows per 42a437a4's merge verdict, then re-raise:
#   set QM_StrategyFarm_ClaudeOrchestration_15min back to --max-sessions 3 after the fix confirms
# stale-task disposition (safe non-candidate rows first):
python tools/strategy_farm/session_tools/apply_stale_task_dispositions.py `
  --plan docs/ops/evidence/2026-09-15_continuous_book_evolution/stale_task_disposition_plan_2026-09-15.csv --apply
# OWNER action: Antigravity relogin to restore the agy critic seat (cross-vendor independence)
```
