# Claude Orchestration Cycle — 2026-05-24 0819Z

## Status: IDLE — No Claude Tasks

### Farm Health
- Overall: **FAIL** (4 fail, 1 warn, 14 ok)
- MT5: **9/10** workers alive (T1 missing — persistent)
- Pending work_items: **684** (was 678 at 0800Z; +6, net new items enqueued)
- Active backtests: **9**

### Fail Checks
| Check | Value | Threshold | Note |
|---|---|---|---|
| p2_pass_no_p3 | 65 | 10 | +0 vs 0800Z; pump action needed |
| unbuilt_cards_count | 605 | 10 | Schema blocker (2507 blocked approved cards) |
| unenqueued_eas_count | 12 | 10 | +0 vs 0800Z |
| p_pass_stagnation | 0 P3+ PASS in 12h | 1 | Pipeline throughput stalled |

### Agent Tasks
- Claude: **0 tasks** (no IN_PROGRESS, no BACKLOG routed)
- Codex: 1 APPROVED build_ea, 2 REVIEW build_ea, 2 APPROVED ops_issue
- Gemini: 1 IN_PROGRESS research_strategy, 5 FAILED research_strategy
- Router: no_routable_task (generic research replenishment frozen — Edge Lab primary)

### QM5_10260 Queue State
- 8 Q02 pending items (AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY)
- **364 items ahead in FIFO** (was 372 at 0800Z; -8 processed this interval)
- All items unclaimed (attempt_count=0); not a skip/ban

### Schema Blocker
- 2507 blocked approved cards (+0 vs 0800Z)
- Fix deployed on agents/board-advisor; CSV commits need `git push origin agents/board-advisor` then OWNER merges to main

### Recommended Actions (OWNER)
1. **Schema blocker**: Merge `agents/board-advisor` → main to unblock 2507 cards and allow auto-build to proceed
2. **p2_pass_no_p3=65**: Run `farmctl pump` manually or check pump scheduling — 65 profitable Q02-pass items stalled without Q03 promotion
3. **T1 terminal**: Still missing; restart if convenient via `start_terminal_workers.py --dedupe`
