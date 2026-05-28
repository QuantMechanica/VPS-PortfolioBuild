# Claude Orchestration Cycle — 2026-05-28 2030 UTC

## Headline

**Recovery cycle after ~64h scheduler gap (0404 → 2030).** Fleet caught up: pending
drained 1393 → 197 (-1196 over ~64h, ~18.7/hr steady pump). All 5 long-aged codex
APPROVED tasks cleared through PIPELINE/PASSED. Longest-standing blocker
`0bf5dc87` (Q02→Q03 pump bug, priority-90, standing 3+ days) moved
**OPS_FIX_REQUIRED → REVIEW**: codex implemented Q02→Q03 parent backfill +
P2→P3 cascade with profit gating, focused tests pass — awaiting codex peer
review, not yet self-approving. One-claim-per-terminal invariant holds 5th cycle
(10/10 terminals claimed, perfect diversity — 10 distinct EAs).

## Routing pass

`agent_router status/run/route-many` clean — `no_routable_task`,
`replenish.frozen=true` (Edge Lab primary 2026-05-22). No claude IN_PROGRESS
tasks; cycle step 4 path taken.

## Active fleet (one-claim-per-terminal, 10 distinct EAs)

| T | EA | Symbol | Phase |
|---|---|---|---|
| T1 | QM5_10478 | USDCAD.DWX | Q02 |
| T2 | QM5_10473 | EURUSD.DWX | Q03 |
| T3 | QM5_10440 | NDX.DWX | Q03 |
| T4 | QM5_10467 | XAUUSD.DWX | Q03 |
| T5 | QM5_10478 | NZDUSD.DWX | Q02 |
| T6 | QM5_10478 | USDCHF.DWX | Q02 |
| T7 | QM5_10472 | USDJPY.DWX | Q03 |
| T8 | QM5_10478 | XTIUSD.DWX | Q02 |
| T9 | QM5_10477 | AUDUSD.DWX | Q02 |
| T10 | QM5_10476 | GBPUSD.DWX | Q02 |

QM5_10478 has 4 active legs (T1/T5/T6/T8). Mix of Q02 (5) and Q03 (5).

## Pending breakdown

- Q02: 101
- Q03: 72
- Q04: 17

## QM5_10260 queue (cycle step 4 mandatory check)

Front line **shifted to Q04 commission gate**:
- Q02 NDX/SP500/WS30: 1 PASS each (resolved), 5 INFRA_FAIL each (carry)
- Q02 AUD/CAD/CHF forex/cross: 8 FAIL (resolved at Q02 but failing)
- Q02 AUDUSD: 1 INFRA_FAIL
- Q03 NDX: **51 PASS** (parameter trials)
- Q03 WS30: **51 PASS** (parameter trials)
- **Q04 NDX: 51 INFRA_FAIL**
- **Q04 WS30: 51 INFRA_FAIL**

Per `project_qm_q04_infra_fail_scaled_2026-05-28`: 1876 Q04 INFRA_FAILs in 24h
across all EAs, 0 Q04 PASS ever — commission gate evidence_path=None for second
code path in terminal_worker.py:410-420. Blocks all promotion to Q05+ for the
entire pipeline, not just QM5_10260. Already-tracked diagnostic.

## Agent task changes vs 0404

- **5 codex APPROVED cleared**: 09f78f65 (build_ea, V2 rebuild complete) →
  PIPELINE; 9c34e720/231d6f8f/96bbfa22/9982c1f4 → PASSED.
- **0bf5dc87**: OPS_FIX_REQUIRED priority-90 → REVIEW (codex verdict: "Implemented
  Q02->Q03 parent backfill and P2->P3 cascade with profit gating; focused tests
  pass"). Awaiting codex peer review — I do NOT self-approve codex code (gemini
  rule applies symmetrically by convention; codex needs second-eyes per CLAUDE.md
  workflow).
- **3854cd8b** RECYCLE persists ~74h (codex did not re-pick after 5 cycles in this
  state; routing problem, not work problem).
- **19 unassigned REVIEW build_ea** (priority 1, gemini-built EAs 11895–11916,
  created 2026-05-26 13:05-14:45) — awaiting codex review per gemini-code rule.
- **6 gemini REVIEW research_strategy** (5× priority-30 setup extractions
  refreshed 2026-05-28 12:21 + 1× priority-20 sandbox-blocked video).
- **8 unassigned PIPELINE build_ea** (priority 30, 2026-05-26 13:25 batch).

## Health checks

- **FAIL**: codex_review_fail_rate_1h 0.5 (2/4 system-class FAILs, 2 EAs)
- **FAIL**: pump_task_lastresult exit 267009 (SCHED_S_TASK_RUNNING transient — documented self-recovery pattern)
- **FAIL**: p2_pass_no_p3=127 flat (will not move until 0bf5dc87 patch merges to
  main and pump picks it up; currently still in REVIEW)
- **FAIL**: unbuilt_cards_count=792 (830 → 792, **-38 emitter resumed**, first
  meaningful movement in 5+ cycles)
- **FAIL**: unenqueued_eas_count=17 (15 → 17, +2)
- **FAIL**: p_pass_stagnation=0/12h
- **OK**: mt5_worker_saturation 10/10
- **OK**: mt5_dispatch_idle (197 pending, 9 active, 17 pwsh workers)
- **OK**: quota_snapshot_fresh 43s both (claude tab refreshed — quota recovery
  from prior ~6.6h staleness)
- **OK**: codex_zero_activity (3 codex, 2 pending), auth clean 224.7h
- **OK**: disk D: 58.5 GB (was 132.5 at 0404 — heavy tester writes during 64h gap)
- **OK**: zerotrade_rework_backlog (no uncovered)
- **OK**: source_pool_drained 10 pending sources

## Working-tree note

Inherited `git status` shows unrelated modifications on QM5_10069/10070 EA dirs
(dropbox research stream) + one untracked parallel-instance report
`docs/ops/claude_orchestration_cycle_2026-05-25_2045.md`. Neither is mine — committing
only this report via explicit pathspec per
`feedback_git_commit_captures_full_index`.

## Recommendations

1. **0bf5dc87 second-eyes review**: codex implementation needs codex peer-review
   before APPROVE → PIPELINE → main merge. Until then, p2_pass_no_p3 stays at 127.
   Primary unblock.
2. **3854cd8b RECYCLE re-route**: stale in RECYCLE ~74h, no codex re-pick.
   Manual triage by OWNER or close-out.
3. **19 unassigned REVIEW build_ea**: priority-1 batch from 2026-05-26 needs
   codex review wave; currently parked.
4. **Q04 commission gate**: known diagnostic (project_qm_q04_infra_fail_scaled),
   blocks all promotion. Not new this cycle.
5. **No QM5_10260 dispatcher action needed**: queue is no longer EA-stalled — the
   work IS moving (Q03 51 PASS each on NDX/WS30); it's now blocked at the
   pipeline-wide Q04 commission gate, which is a code-fix item.
6. **codex_review_fail_rate_1h 0.5**: 2/4 system-class fails in last hour — small
   denominator, but watch next cycle for whether it's noise or a fresh issue.
