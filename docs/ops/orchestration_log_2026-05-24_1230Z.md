# Claude Orchestration Cycle — 2026-05-24 1230Z

## Status: IDLE — No Claude Tasks

### Farm Health
- Overall: **FAIL** (3 fail, 2 warn, 14 ok)
- MT5: **9/10** workers alive (T1 missing — persistent)
- Pending work_items: **597** (unchanged vs 1215Z)
- Active backtests: **9**

### Fail Checks
| Check | Value | Threshold | Note |
|---|---|---|---|
| p2_pass_no_p3 | 71 | 10 | +0 vs 1215Z; pump action needed |
| unbuilt_cards_count | 589 | 10 | Schema blocker (2511 blocked approved cards) |
| p_pass_stagnation | 0 P3+ PASS in 12h | 1 | Pipeline throughput stalled |

### Warn Checks
| Check | Value | Threshold | Note |
|---|---|---|---|
| mt5_worker_saturation | 9/10 | 10 | T1 still missing; fleet >2/3 ok |
| unenqueued_eas_count | 9 | 3 | QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079 |

### Agent Tasks
- Claude: **0 tasks** (no IN_PROGRESS, no BACKLOG routed)
- Codex: 3 APPROVED build_ea, 2 APPROVED ops_issue (0 running — awaiting Codex pickup)
- Gemini: 1 IN_PROGRESS research_strategy, 5 FAILED research_strategy
- Router: no_routable_task (generic research replenishment frozen — Edge Lab primary; 0 ready cards)

### QM5_10260 Queue State
- 8 Q02 pending items (all unclaimed, attempt_count=0)
- **337 items ahead in FIFO** (was 273 at 1215Z; **+64 regression**)
- Regression likely caused by recycled/failed items reverting to pending with earlier rowids; not a skip/ban on QM5_10260 itself

### Schema Blocker
- 2511 blocked approved cards (+0 vs 1215Z)
- Fix deployed on agents/board-advisor; CSV commits need `git push origin agents/board-advisor` then OWNER merges to main

### Recommended Actions (OWNER)
1. **Schema blocker**: Merge `agents/board-advisor` → main to unblock 2511 cards and allow auto-build to proceed
2. **p2_pass_no_p3=71**: Run `farmctl pump` manually or check pump scheduling — 71 profitable Q02-pass items stalled without Q03 promotion
3. **T1 terminal**: Still missing; restart if convenient via `start_terminal_workers.py --dedupe`
4. **QM5_10260 FIFO regression**: +64 items ahead vs last cycle — monitor; if position does not recover in 2–3 cycles, investigate recycle storm or queue ordering issue
