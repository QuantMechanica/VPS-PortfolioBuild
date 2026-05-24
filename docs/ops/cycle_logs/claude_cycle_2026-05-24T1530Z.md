# Claude Orchestration Cycle — 2026-05-24T1530Z

## Status: IDLE — no claude tasks

## Health (farmctl)

| Check | Status | Detail |
|---|---|---|
| overall | **FAIL** | 3 FAIL / 2 WARN / 14 OK |
| p2_pass_no_p3 | FAIL | 92 profitable P2-PASS work_items with no P3 promotion |
| unbuilt_cards_count | FAIL | 585 approved cards lack .ex5 (auto-build bridge frozen) |
| p_pass_stagnation | FAIL | 0 P3+ PASS verdicts in last 12h |
| mt5_worker_saturation | WARN | 9/10 daemons alive — T1 missing |
| unenqueued_eas_count | WARN | 9 reviewed built EAs have no Q02 work_items |
| mt5_dispatch_idle | OK | 629 pending / 9 active / 8 terminal64 running |
| pump_task_lastresult | OK | last run exit 0 |
| disk_free_gb | OK | D: 175 GB free |

## Router state

- **claude**: 0 running, 0 BACKLOG/TODO — nothing to route
- **codex**: 5 APPROVED tasks (3 build_ea + 2 ops_issue) — pipeline value locked in, awaiting Codex pickup
- **gemini**: 1 IN_PROGRESS (research_strategy — retrying sandbox verification)
- `route-many --max-routes 5` → no_routable_task (no BACKLOG/TODO items in queue)
- Research replenishment frozen: `generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`
- Approved cards: 2512 total / 2512 blocked / 0 ready

## Active backtests

QM5_10128 running Q02 on T2 (AUDJPY.DWX) and T3 (AUDCHF.DWX) at cycle time; 562 Q02 items pending.

## QM5_10260 queue state

0 work_items in DB. Memory: Q02 TIMEOUT on all 37 symbols as of 2026-05-22 re-run; perf rework APPROVED by Codex but never confirmed resolved. No active agent_task exists for this EA currently.

## Findings for OWNER

### T1 worker daemon down
Terminal T1 absent from `terminal_workers` — 9/10 saturation. Not critical (629 items queued, 9 workers active). Restart path: Factory toggle in OWNER RDP session or `start_terminal_workers.py --dedupe` after login.

### p2_pass_no_p3 FAIL (88 items / 3 EAs)
Direct DB query: 288 P2/done/PASS items across QM5_10023 (195), QM5_10026 (57), QM5_10042 (36). None have P3 rows. These are old-pipeline EAs. Farmctl health reports 92 "profitable" (its filter); pump ran exit 0 but did not promote.

- QM5_10026: Codex APPROVED build task 9982c1f4 (rolling-window fix); verdict says "proceed to enqueue Q02." If Q02 re-run pass, P2 promotion is moot (old pipeline superseded).
- QM5_10023 and QM5_10042: no recent build task — old P2 results. P3 enqueue likely blocked by missing Q02 results or pump gate condition.

**Action needed**: OWNER or Codex should verify whether P2→P3 pump gate is intentionally disabled for old-pipeline EAs now that Q-pipeline is live, or whether these 3 EAs need explicit Q02 enqueue.

### QM5_10260 still unqueued
No work_items, no active agent_task. Perf fix unconfirmed. If OWNER wants this EA back in queue, a new Codex ops_issue task should be opened to verify/apply the FOMC cycle index performance fix and re-enqueue for Q02.

### 585 unbuilt cards blocked
All 2512 approved cards show `blocked_approved_cards=2512`. Router `ready_approved_cards=0`. This persists from the schema/universe-mismatch blockers noted 2026-05-23. Codex schema-blocker fix (agents/board-advisor) needs `git push origin agents/board-advisor` + OWNER merge to main before auto-build resumes.

## Evidence
- farmctl health output: in-process (not persisted — use `farmctl.py health` to re-run)
- DB snapshot: `D:/QM/strategy_farm/state/farm_state.sqlite` at 2026-05-24T15:36Z
