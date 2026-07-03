# Claude Orchestration Cycle — 2026-07-03T0600Z

## Summary
- **IN_PROGRESS at start:** 1 (stale lease from prior cycle, expired during `run`)
- **IN_PROGRESS after routing:** 0
- **Work executed this cycle:** none — no tasks successfully moved to IN_PROGRESS

## Health (farmctl health)
| Check | Status | Value |
|-------|--------|-------|
| p2_pass_no_p3 | **FAIL** | 127 profitable P2-PASS without P3 |
| unbuilt_cards_count | **FAIL** | 786 approved cards lack .ex5 |
| unenqueued_eas_count | **FAIL** | 65 built EAs with no Q02 work items |
| p_pass_stagnation | **FAIL** | 0 P3+ PASS verdicts in last 12h |
| mt5_worker_saturation | WARN | 7/10 workers alive (T1–T7) |
| source_pool_drained | WARN | 7 pending sources |
| quota_snapshot_fresh | WARN | 326s (just over 300s threshold) |
| All other checks | OK | — |

Overall: **FAIL** (4 fail, 3 warn, 12 ok)

## Routing events

### `agent_router.py run --min-ready-strategy-cards 5 --max-routes 5`
- 1 route attempted: task `d015e982` (ops_issue, priority 2) → `no_available_agent`
- Replenishment: frozen (60 ready cards ≥ 5 threshold)

### `agent_router.py route-many --max-routes 5`
- Same result: `d015e982` still `no_available_agent`

### Root cause of unroutable task
Task `d015e982` (created 2026-07-03T05:36Z, priority 2, assigned_agent=claude, state=TODO) requires capabilities `["code", "repo", "ops"]`. No registered agent has `"repo"` (Codex has `"repo_edit"`, not `"repo"`). This is a capability-string mismatch bug — the task was likely intended for Codex (`code + repo_edit + ops`) but was created with `"repo"` instead of `"repo_edit"`.

**Goal of d015e982:** Follow-up to b80ee365: (1) phase active-timeouts scale with workload in farmctl (`_active_timeout_min_for_work_item`); (2) `update_magic_resolver.py` strict-mode warning with dropped-rows list. Both are Codex-scope ops changes.

**Action needed:** Fix `required_capabilities_json` from `["code","repo","ops"]` → `["code","repo_edit","ops"]` and reassign to `codex`. Cannot be done inside the deterministic router by Claude without OWNER authorization.

## QM5_10260 queue state
279 work items total. Pipeline position:

| Phase | Verdict | Count |
|-------|---------|-------|
| Q02 | PASS | 16 |
| Q02 | FAIL | 8 |
| Q02 | INFRA_FAIL | 4 |
| Q03 | PASS | 115 |
| Q04 | PASS | 5 |
| Q04 | FAIL | 110 |
| Q05 | PASS | 5 |
| Q06 | PASS | 5 |
| Q07 | PASS | 3 |
| Q07 | FAIL | 2 |
| Q08 | FAIL_HARD | 3 |

**Status:** EA reached Q08 on 3 symbols but FAIL_HARD on all three. This is the correct hard-gate behavior; no routing action required from Claude. The ops_issue for QM5_10260 (b80ee365 and d015e982) is Codex-scope.

## Claude APPROVED task backlog (top 5 by priority)
| Priority | Task ID | Type | Summary |
|----------|---------|------|---------|
| 2 | 54387422 | ops_issue | QM5_10069 Q08 FAIL_HARD — truncated q08_trades stream |
| 2 | bffea48b | ops_issue | 1,242 terminal 0-trade FAILs — missing strategy_params |
| 3 | c57721a9 | ops_issue | Q09 portfolio admission challenger-swap (OWNER 2026-07-03) |
| 3 | d4cc2b7c | research_strategy | SOLO XNGUSD strategies |
| 4 | 44ae5229 | research_strategy | SOLO XAGUSD strategies |

These remain APPROVED; the router did not move any to IN_PROGRESS this cycle.

## Action items for OWNER
1. **Fix task d015e982:** Change `required_capabilities_json` to `["code","repo_edit","ops"]` and set `assigned_agent=codex` — currently stranded with no capable agent.
2. **Source pool:** 7 sources remaining; approaching FAIL threshold (10). New source intake needed soon.
3. **T8–T10 offline:** Workers 7/10. If T8–T10 are intentionally off (FTMO Codex terminals per memory), no action; otherwise check.
4. **p_pass_stagnation:** 0 P3+ verdicts in 12h. Factory is running (5934 pending, 6 active) but no pipeline advances. Could be Q04 commission gates filtering; monitor next cycle.
