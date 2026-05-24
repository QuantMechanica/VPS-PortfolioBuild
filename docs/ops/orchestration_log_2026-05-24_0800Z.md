# Claude Orchestration Cycle — 2026-05-24 0800Z

## Status: IDLE — No Claude Tasks

### Farm Health
- Overall: **FAIL** (4 fail, 1 warn, 14 ok)
- MT5: **9/10** workers alive (T1 missing — persistent)
- Pending work_items: **678** (was 705 at 0730Z; -27, active processing confirmed)
- Active backtests: **9**

### Fail Checks
| Check | Value | Threshold | Note |
|---|---|---|---|
| p2_pass_no_p3 | 65 | 10 | +0 vs 0730Z; pump action needed |
| unbuilt_cards_count | 605 | 10 | Schema blocker (2507 blocked approved cards) |
| unenqueued_eas_count | 12 | 10 | +0 vs 0730Z |
| p_pass_stagnation | 0 P3+ PASS in 12h | 1 | Pipeline throughput stalled |

### Agent Tasks
- Claude: **0 tasks** (no IN_PROGRESS, no BACKLOG routed)
- Codex: 1 APPROVED build_ea, 2 REVIEW build_ea, 2 APPROVED ops_issue
- Gemini: 1 IN_PROGRESS research_strategy, 5 FAILED research_strategy
- Router: no_routable_task (generic research replenishment frozen — Edge Lab primary)

### QM5_10260 Queue State
- 8 Q02 pending items (AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY)
- **372 items ahead in FIFO** (was 386 at 0730Z; -14 processed this interval — on track)
- All items unclaimed (attempt_count=0); not a skip/ban
- ETA: ~372 items / 9 workers — will reach QM5_10260 in due course

### Schema Blocker
- 2507 blocked approved cards (+1 vs 0730Z)
- Fix deployed on agents/board-advisor; CSV commits need `git push origin agents/board-advisor` then OWNER merges to main

### Recommended Actions (OWNER)
1. **Schema blocker**: Merge `agents/board-advisor` → main to unblock 2507 cards and allow auto-build to proceed (unbuilt_cards=605 drops once cards are accessible)
2. **p2_pass_no_p3=65**: Run `farmctl pump` manually or check pump scheduling — 65 profitable Q02-pass items stalled without Q03 promotion
3. **T1 terminal**: Still missing; restart if convenient via `start_terminal_workers.py --dedupe`
