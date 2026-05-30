# Orchestration Cycle Log — 2026-05-30T1200Z

## Status: CLEAN — no Claude tasks, factory running

## Health snapshot

| Check | Status | Value |
|---|---|---|
| mt5_worker_saturation | OK | 10/10 daemons alive (T1–T10) |
| mt5_dispatch_idle | OK | 298 pending, 5 active, 23 pwsh workers |
| active_row_age | OK | no rows beyond phase timeout |
| p2_pass_no_p3 | OK | 0 pending promotion |
| pump_task_lastresult | OK | last run exit 0 |
| codex_zero_activity | OK | 1 codex active, 10 pending |
| quota_snapshot_fresh | OK | codex=43s, claude=43s |
| codex_auth_broken | OK | no 401 errors |
| unbuilt_cards_count | **FAIL** | 661 approved cards lack .ex5 (pump auto-build managing) |
| disk_free_gb | **WARN** | **D: free = 15.4 GB** (threshold 25 GB) |
| source_pool_drained | WARN | 9 pending sources (threshold 10) |
| cards_ready_stagnation | WARN | 1 actionable source |

Overall: FAIL (driven by unbuilt_cards_count and disk_free_gb)

## Routing results

- `agent_router run --min-ready-strategy-cards 5 --max-routes 5` → `no_routable_task`
- `agent_router route-many --max-routes 5` → `no_routable_task`
- Research replenishment frozen: 1017 ready approved cards >> 5 threshold — correct
- `list-tasks --agent claude --state IN_PROGRESS` → empty list

No Claude tasks were routed or exist. Cycle complete with no work items.

## QM5_10260 queue state (do not interrupt)

| Phase | Status | Verdict | Count |
|---|---|---|---|
| Q02 | done | PASS | 3 |
| Q02 | done | FAIL | 7 |
| Q02 | done | INFRA_FAIL | 15+1=16 |
| Q03 | done | PASS | 102 |
| Q04 | done | FAIL | 45 |
| Q04 | done | PASS | 1 |
| Q04 | active | — | 1 |
| Q04 | pending | — | 55 |
| Q05 | active | — | 1 |

55 Q04 pending + 2 active. Verdict deferred until pending=0 per standing instruction.
Current Q04 sweep: FAIL=45, PASS=1. No additional verdict warranted at this time.

## D: disk pressure — OWNER attention required

**D: 938.5 GB used, 15.4 GB free.** Risk: if D: fills completely, the factory stalls.

Top consumers:
| Path | Size |
|---|---|
| D:\QM\mt5 (T1–T10 tester data) | 744 GB |
| D:\QM\reports\work_items | 138 GB |
| D:\QM\reports\smoke | 5 GB |
| D:\QM\strategy_farm | 3 GB |

The `reports/work_items/` directory (138 GB of MT5 backtest HTML reports) is the most actionable cleanup target — completed work_items reports older than some cutoff can likely be deleted without losing any pipeline evidence (evidence_path in the DB points to these; farmctl/farm logic must be verified before bulk delete). The farmctl health hint suggests "rotating logs older than 30 days."

**Recommended action for OWNER:** decide a retention policy for D:\QM\reports\work_items (e.g. delete reports for work_items with status=done older than 30 days). Do not autonomously delete — this requires OWNER sign-off. A 30-day cull of D:\QM\reports\work_items could recover ~100+ GB.

The MT5 tester data (744 GB across T1–T10) is harder to reduce without affecting backtest history availability.

## Other observations

- Codex has 1 IN_PROGRESS ops_issue + 1 APPROVED ops_issue (likely edge lab INFRA_FAIL task 231d6f8f, stalled since 2026-05-23)
- 6 Gemini research_strategy tasks in APPROVED state — awaiting Gemini pick-up
- 19 RECYCLE build_ea tasks — pump will requeue in due course

## Recommended next step

1. **OWNER: review D: disk cleanup options** — approve a retention policy for reports/work_items before D: hits critical (<5 GB)
2. Monitor QM5_10260 until Q04 pending=0; then assess verdict
3. No farm changes needed this cycle
