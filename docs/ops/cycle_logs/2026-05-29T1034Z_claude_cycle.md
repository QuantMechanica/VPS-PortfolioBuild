# Claude Orchestration Cycle — 2026-05-29T1034Z

## Status: IDLE — no Claude tasks

## Health (farmctl)
- **OVERALL: FAIL** (4 FAIL, 1 WARN, 14 OK)
- FAIL `p2_pass_no_p3`: 127 Q02-PASS work_items stranded without Q03 (§10c pump bug, push-blocked on PAT)
- FAIL `unbuilt_cards_count`: 777 approved cards without .ex5 / auto-build task
- FAIL `unenqueued_eas_count`: 17 reviewed built EAs with no Q02 work_items
- FAIL `p_pass_stagnation`: 0 Q03+ PASS verdicts in last 12h
- WARN `source_pool_drained`: 9 pending sources (threshold 10)
- OK: 10/10 terminal workers alive, 372 pending + 10 active MT5 backtests, D: free 44.9 GB

## Router
- Claude: 0 running, 0 IN_PROGRESS tasks
- Gemini: 1 IN_PROGRESS + 2 REVIEW + 4 APPROVED research_strategy
- Codex: 0 running, mix of PASSED/PIPELINE/RECYCLE build_ea + ops_issue
- `ready_approved_cards: 0` (all 2674 approved cards blocked)
- `no_routable_task` from both `run` and `route-many`
- Research replenishment frozen: `generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`

## QM5_10260 Queue State
- Q02: 3 PASS, 7 FAIL, 16 INFRA_FAIL
- Q03: 102 PASS (perf rework working)
- Q04: 2 pending, 100 INFRA_FAIL (known commission file issue — $0 commission on .DWX; Codex task f308fe3f pending)

## Blockers (carry-forward)
- PAT refresh required to unblock §10c pump bug (154 cycle heartbeats trapped across worktrees)
- Q04 commission gate broken — all .DWX symbols tested at $0; fix specced (d04f2611), Codex task f308fe3f
- DL-062 v2 ea_dir_ambiguous: 4 EAs blocked at Q02

## Action
None — no routable tasks for Claude this cycle.
