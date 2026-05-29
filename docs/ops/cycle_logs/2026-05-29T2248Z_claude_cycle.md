# Claude Orchestration Cycle — 2026-05-29T2248Z

## Status
No Claude IN_PROGRESS tasks. No routable tasks for Claude this cycle. Factory running normally.

## Farm Health
- **Overall: FAIL** (1 fail, 2 warn, 17 ok)
- FAIL: `unbuilt_cards_count` = 661 — approved cards without .ex5 or auto-build task; pump should emit up to 2 auto-build bridge tasks per cycle
- WARN: `disk_free_gb` = 18.7 GB on D: (threshold 25 GB) — approaching critical; log rotation recommended
- WARN: `source_pool_drained` = 9 pending sources (threshold 10) — research replenishment frozen per generic freeze (1,017 ready cards >> 5 threshold)
- OK: `mt5_worker_saturation` = 10/10 workers alive
- OK: `mt5_dispatch_idle` = 329 pending work_items, 4 active, 6 fresh logs
- OK: `p2_pass_no_p3` = 0 (no stuck promotions)

## Agent Router
- Claude: 0 running / 3 max — `no_routable_task` from both `run` and `route-many`
- Codex: 1 IN_PROGRESS (ops_issue), 9 PIPELINE build_ea tasks
- Gemini: 0 running — 6 APPROVED research_strategy tasks (Dropbox video extraction + quantocracy; G0 reviews completed in prior cycles)
- Generic research replenishment frozen; 1,017 ready strategy cards in inventory

## Task State Summary
| type | agent | state | count |
|---|---|---|---|
| build_ea | codex | PASSED | 2 |
| build_ea | null | PIPELINE | 8 |
| build_ea | codex | PIPELINE | 1 |
| build_ea | null | RECYCLE | 19 |
| ops_issue | null | APPROVED | 3 |
| ops_issue | codex | IN_PROGRESS | 1 |
| ops_issue | codex | PASSED | 2 |
| ops_issue | codex | RECYCLE | 3 |
| research_strategy | gemini | APPROVED | 6 |
| research_strategy | gemini | RECYCLE | 1 |

## APPROVED Ops Issues (unassigned — require Codex routing)
1. **0618055e** (priority 20): Fix §10c P3 promoter profit-check — align `farmctl.py _work_item_p2_net_profit` with `health.py` recovered_stats fast-path; 127 profitable stuck items blocked
2. **af9d128a** (priority 15): Q08 trade log infrastructure — "requires_owner_decision" flag still set; NOTE: memory records Q08 fix committed (5e574572 + b8c4bcd2) 2026-05-29T1430Z; Codex should verify whether this ops_issue is stale before acting
3. **43ca200e** (priority 10): Fix `aggregate.py` sys.path `parents[2]→parents[3]` — git commit task; memory records fix applied; Codex should verify commit reachable on origin/main

## QM5_10260 Queue State
- 230 work_items, all status=`done`, all verdict=`FAIL` at Q02
- Confirmed eliminated per memory (NDX+WS30 both Q04 FAIL 2026-05-29T1215Z)
- No pending items; cieslak-fomc-cycle-idx strategy fully rejected

## Actions Taken
- None; no Claude-assigned work this cycle
- Router routes correctly: code/repo_edit ops_issues route to Codex, not Claude
- Gemini research_strategy tasks are pre-reviewed (G0 APPROVED verdicts in payload); awaiting Gemini execution

## Blockers / Risks
- D: disk at 18.7 GB — if D: fills, MT5 workers will fail to write reports; rotate logs >30 days
- 661 unbuilt cards — pump auto-build bridge is the resolution path; no manual action needed this cycle
- ops_issues `af9d128a` and `43ca200e` may be stale (Q08 fix already applied per memory); OWNER or Codex should close them if verified
