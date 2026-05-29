# Claude Orchestration Cycle — 2026-05-29T0918Z

## Status

No IN_PROGRESS tasks. No routable tasks returned by `route-many`. Cycle exits cleanly.

## Farm Health (checked 2026-05-29T0915Z)

Overall: **FAIL** — 4 failures, 1 warning, 14 OK

| Check | Status | Detail |
|---|---|---|
| p2_pass_no_p3 | FAIL | 127 Q02-PASS work_items without Q03 promotion (pump §10c bottleneck) |
| unbuilt_cards_count | FAIL | 786 approved cards lack .ex5 and auto-build task |
| unenqueued_eas_count | FAIL | 17 reviewed built EAs have no Q02 work_items |
| p_pass_stagnation | FAIL | 0 Q03+ PASS verdicts in last 12h |
| source_pool_drained | WARN | 9 pending sources (threshold 10) |
| mt5_worker_saturation | OK | 10/10 workers alive |
| mt5_dispatch_idle | OK | 321 pending, 5 active |
| codex_auth_broken | OK | no 401 errors (auth age 237.5h) |

## Router State

- Research replenishment: **frozen** (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`)
- Ready approved cards: 0 (2674 approved, all blocked)
- `route-many --max-routes 5`: returned `no_routable_task`
- Claude tasks: **none** (list-tasks returns [])
- Gemini: 4 APPROVED + 2 REVIEW research_strategy tasks (not Claude's to touch)
- Codex: 1 PIPELINE build_ea, 2 PASSED build_ea

## QM5_10260 Queue State

| Phase | Status | Verdict | Count |
|---|---|---|---|
| Q02 | done | FAIL | 7 |
| Q02 | done | INFRA_FAIL | 15 |
| Q02 | done | PASS | 3 |
| Q02 | failed | INFRA_FAIL | 1 |
| Q03 | done | PASS | 102 |
| Q04 | failed | INFRA_FAIL | 102 |

QM5_10260 at Q04: 102 INFRA_FAIL confirming the recompile blocker (EAs built before `QM_Common.mqh` gained `InpQMSimCommissionPerLot` via commit 541bfdd8). Memory note from 2026-05-29 stands: no Codex ops_issue for bulk recompile+re-queue exists yet.

## Q04 Ecosystem State

| Status | Verdict | EAs | Items |
|---|---|---|---|
| active | — | 3 | 3 |
| done | FAIL | 5 | 47 |
| failed | INFRA_FAIL | 46 | 3864 |
| failed | INVALID | 13 | 70 |
| pending | — | 2 | 2 |

**3864 INFRA_FAILs across 46 EAs** = Q04 recompile blocker still active. 3 Q04 backtests running live.

## Active Pipeline Queue

- Q02 pending: 249
- Q03 active: 2 | Q03 pending: 68
- Q04 active: 3 | Q04 pending: 2

## Issues Flagged for OWNER

### 1. Q04 recompile blocker — OWNER action required
46 EAs (3864 work_items) stuck at Q04 INFRA_FAIL because they were compiled before `InpQMSimCommissionPerLot` was added to `QM_Common.mqh` (commit 541bfdd8). Zero Q04 PASSes since commission gate activation. **No Codex ops_issue task exists for bulk recompile + re-queue.** OWNER needs to direct Codex to create this ops_issue.

### 2. farmctl pipeline command crash
`farmctl.py pipeline` crashes with `AttributeError: 'str' object has no attribute 'get'` on line 1093 — `build_result` is a raw string in some agent_task payload rows. Codex fix needed.

### 3. p2_pass_no_p3: 127 Q02-PASS EAs
Pump §10c still not promoting Q02-PASS to Q03 for 127 work_items. The Q02→Q03 pump fix (committed af9ce5f1 on agents/board-advisor) is unmerged pending PAT refresh.

## Next Cycle

No work for Claude this cycle. All blockers are either OWNER-decision gates or Codex ops_issue work.
